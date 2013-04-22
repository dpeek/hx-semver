package mtask.target;

import mtask.target.Target;

class Flash extends App
{
	var fontHaxeArgs:Array<String>;

	public function new()
	{
		super();
		flags.push("flash");
		addMatcher(".+\\.(ttf|otf)$", processFonts);
	}

	function processFonts(files:Array<TargetFile>)
	{
		fontHaxeArgs = [];

		for (file in files)
		{
			var source = file.absolute;
			var basename = msys.Path.basename(source);
			var output = ".temp/mtask/font/" + basename.split(".").slice(0, -1).join(".") + ".swf";

			// add to args
			fontHaxeArgs.push("-swf-lib");
			fontHaxeArgs.push(output);

			// abort if already generated
			if (exists(output)) continue;
			var name = basename.split(".")[0];
			
			var family = ~/[_-]?(Bold|Regular|Italic)/g.replace(name, "");
			var fontArgs = ["-a", family, "-3"];
			if (basename.indexOf("Bold") > -1) fontArgs.push("-bold");
			if (basename.indexOf("Italic") > -1) fontArgs.push("-italic");

			fontArgs.push("-o");
			fontArgs.push(output);
			fontArgs.push(source);
			
			// generate
			if (!exists(".temp/mtask/font")) mkdir(".temp/mtask/font");
			mtask.tool.Flex.fontswf(fontArgs);
		}
	}

	override function processAssetLibrary(id:String, files:Array<TargetFile>)
	{
		super.processAssetLibrary(id, files);

		var hxmls = [];
		var swf = path + "/asset/" + id + ".swf";
		hxmls.push("-swf " + swf);
		hxmls.push("-lib mtask");

		for (file in files)
		{
			var path = msys.Path.split(file.local).join(".");
			hxmls.push("--macro mtask.target.ImageMacro.embed('"+file.absolute+"','asset."+path+"')");
		}

		var hxml = ".temp/mtask/asset.hxml";
		write(hxml, hxmls.join("\n"));
		mtask.core.Process.run("haxe", [hxml]);
	}

	override public function getHaxeArgs():Array<String>
	{
		var args = super.getHaxeArgs();
		
		args.push("-swf-header");
		args.push(width + ":" + height + ":60:" + backgroundHex);

		if (debug)
		{
			// enable flash debugger for debug builds
			args.push("-D");
			args.push("fdb");
		}

		if (fontHaxeArgs != null)
		{
			for (arg in fontHaxeArgs) args.push(arg);
		}
		
		return args;
	}

	override public function run()
	{
		openURL(path);
	}
}
