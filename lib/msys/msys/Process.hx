package msys;

#if sys
typedef NativeProcess = sys.io.Process;
#elseif neko
typedef Sys = neko.Sys;
typedef NativeProcess = neko.io.Process;
#elseif cpp
typedef Sys = cpp.Sys;
typedef NativeProcess = cpp.io.Process;
#end

#if neko
typedef Thread = neko.vm.Thread;
#elseif cpp
typedef Thread = cpp.vm.Thread;
#end

typedef PrintStream =
{
	@:optional var out:String->Void;
	@:optional var err:String->Void;
}

class Process
{
	public static function run(command:String, ?args:Array<String>, ?printer:PrintStream):Int
	{
		if (args == null) args = [];
		
		var printStream:PrintStream = {}; // avoid modifying original printer
		if (printer == null)
		{
			// Only print command if not redirecting
			Console.warn(command + " " + args.join(" "));
		}
		else
		{
			printStream.out = printer.out;
			printStream.err = printer.err;
		}
		
		if (printStream.out == null) printStream.out = function(line:String) { trace(line); }
		if (printStream.err == null)
		{
			printStream.err = function(line:String)
			{
				var s = line.toLowerCase();
				if (s.indexOf("warning") != -1 && s.indexOf("error") == -1) Console.warn(line);
				else untyped Console.print(mconsole.LogLevel.error, [line], mcore.util.Reflection.here());
			}
		}

		var process = new NativeProcess(command, args);

		// If the target supports it, spawn a new thread to stream stderr and stdout in parallel 
		#if (neko || cpp)
		var monitor = Thread.create(function()
		{
			var process:NativeProcess = Thread.readMessage(true);
			var printer:PrintStream = Thread.readMessage(true);
			streamInput(process.stderr, printer.err);
		});
		monitor.sendMessage(process);
		monitor.sendMessage(printStream);

		streamInput(process.stdout, printStream.out);
		#else
		streamInput(process.stdout, printStream.out);
		var error = process.stderr.readAll().toString();
		printStream.err(error);
		#end

		return process.exitCode();
	}

	static function streamInput(input:haxe.io.Input, print:String->Void)
	{
		try
		{
			while (true)
			{
				print(input.readLine());
			}
		}
		catch (e:haxe.io.Eof) {}
	}

	public static function read(command:String, ?args:Array<String>)
	{
		if (args == null) args = [];

		var process = new NativeProcess(command, args);
		if (process.exitCode() == 0)
		{
			var stdout = process.stdout.readAll().toString();
			return StringTools.trim(stdout);
		}

		return null;
	}

	public static function open(target:String)
	{
		var exit = 0;
		if (System.isWindows)
		{
			if (System.isCygwin) exit = Sys.command("bash", ["-c", "'open " + target + "'"]);
			else exit = Sys.command("start", [target]);
		}
		else
		{
			exit = Sys.command("open", [target]);
		}

		if (exit != 0)
		{
			throw new mcore.exception.Exception("Failed to open " + target);
		}
	}
}
