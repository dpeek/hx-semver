package mtask.target;

class HaxeDoc extends Target
{
	public function new()
	{
		super();
		flags.push("haxedoc");
	}

	override function compile()
	{
		msys.FS.cd(path, function(path){
			cmd("haxedoc", ["haxedoc.xml"]);
		});
	}
}
