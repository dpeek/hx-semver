package mtask.core;

/**
	A helper utility for working with processes in mtask
**/
class Process
{
	/**
		Execute a process and return its stdout or stderr (depending on the 
		process exit code)
	**/
	public static function run(cmd:String, ?args:Array<String>, ?print:Bool=true):String
	{
		if (args == null) args = [];
		if (print) Console.warn([cmd].concat(args).join(" "));
		
		// indent output
		if (print) untyped Console.groupDepth += 1;

		var process = new sys.io.Process(cmd, args);
		var output = "";
		
		process.stdin.writeString("a\n");

		while (true)
		{
			try
			{
				var line = process.stdout.readLine();
				output += line + "\n";
				
				if (print)
				{
					trace(line);
					Sys.stdout().flush();
				}
			}
			catch (e:haxe.io.Eof) break;
		}
		
		if (print) untyped Console.groupDepth -= 1;
		var exitCode = process.exitCode();

		if (exitCode != 0)
		{
			var error = process.stderr.readAll().toString();
			error = StringTools.trim(error);
			error = error.split("\n").join("\n  ");
			throw new mtask.core.Error("Process '" + cmd + "' exited with code '" + exitCode + "':\n  " + error);
		}
		
		return StringTools.trim(output);
	}
}
