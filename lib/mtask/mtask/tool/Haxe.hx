package mtask.tool;

import sys.io.Process;

class Haxe
{
	public static function command(args:Array<String>):String
	{
		if (serverThread != null)
		{
			// use Haxe server if it is running
			args.push("--connect");
			args.push(Std.string(serverPort));
		}

		return mtask.core.Process.run("haxe", args);
	}

	/**
	Filters a Haxe 'types' xml on the path of each type.

	`filters` should be an array of strings to match against the beginning of 
	each type path. eg ["mmvc","msignal","Array","List"]
	*/
	public static function filterXml(path:String, filters:Array<String>):Void
	{
		var types = Xml.parse(msys.File.read(path));

		var filtered = Xml.createDocument();
		var root = Xml.createElement("haxe");
		filtered.addChild(root);

		for (element in types.firstElement().elements())
		{
			var path = element.get("path");

			for (filter in filters)
			{
				if (path.indexOf(filter) == 0)
				{
					root.addChild(element);
					break;
				}
			}
		}

		msys.File.write(path, filtered.toString());
	}

	//-------------------------------------------------------------------------- server

	/**
	The Haxe server thread.
	*/
	static var serverThread:neko.vm.Thread;

	/**
	The port to run the Haxe server on.
	*/
	public static var serverPort:Int = 4444;

	/**
	Starts the Haxe server if it is not already running.
	*/
	public static function startServer()
	{
		if (serverThread == null)
		{
			serverThread = neko.vm.Thread.create(serverMain);
		}
	}

	/**
	Stops the Haxe server if it is not already running.
	*/
	public static function stopServer()
	{
		if (serverThread != null)
		{
			serverThread.sendMessage(1);
			serverThread = null;
		}
	}

	/**
	The server thread entry point.
	*/
	static function serverMain()
	{
		Console.warn("haxe --wait " + serverPort);
		var process = new Process("haxe", ["--wait", Std.string(serverPort)]);
		if (neko.vm.Thread.readMessage(true)) process.kill();
	}
}
