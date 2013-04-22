package mtask.target;

class Doc extends Target
{
	public function new()
	{
		super();
		flags.push("doc");
	}

	override function configure()
	{
		super.configure();

		mtask.tool.HaxeLib.require("chxdoc");
		mtask.tool.HaxeLib.require("HaxeUmlGen");
	}

	override function compile()
	{
		super.compile();
		
		msys.FS.cd(path, function(path){
			try
			{
				mtask.core.Process.run("chxdoc", ["--config", "config.xml", "-f", "haxedoc.xml", "--tmpDir=temp"]);
			}
			catch (e:Dynamic)
			{
				var message = Std.string(e);
				if (message.indexOf("Command not found") > -1 || message.indexOf("Process creation failure") > -1)
				{
					var msg = "Please install the chxdoc by running `haxelib run chxdoc install {path}`";
					throw new mtask.core.Error(msg);
				}
				else throw e;
			}

			// cmd("neko", ["${lib.mtask}uml.n", "dot", "-c", "-o", "uml", "haxedoc.xml"]);
			rm("temp");
		});
	}

	override public function run()
	{
		openURL(path);
	}
}
