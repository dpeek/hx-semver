package mtask.target;

class XCross extends Target
{
	public function new()
	{
		super();
		flags.unshift("xcross");
	}

	override function compile()
	{
		mtask.tool.HaxeLib.require("xcross");
		
		var files = msys.FS.ls(path + "/*.n");
		if (files.length == 0) throw "There is no neko binary to process!";
		
		var file = files[0];
		var basename = msys.Path.basename(file);
		var filename = msys.Path.basename(file, ".n");

		msys.FS.cd(path, function(path){
			mtask.tool.HaxeLib.run("xcross", ["-bundle", filename + "-osx", basename]);
		});
	}
}
