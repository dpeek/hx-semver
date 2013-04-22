package mtask.tool;

class AIR
{
	public static function adt(args:Array<String>)
	{
		run("adt", args);
	}

	public static function adl(args:Array<String>)
	{
		run("adl", args);
	}

	static function run(tool:String, args:Array<String>)
	{
		var bin = getHome() + "/bin/" + tool;
		
		if (msys.System.isWindows)
		{
			if (msys.File.exists(bin + ".bat")) bin += ".bat";
			else if (msys.File.exists(bin + ".exe")) bin += ".exe";
			else throw "There is no windows executable for the AIR tool '" + tool + "'";
		}

		mtask.core.Process.run(bin, args);
	}

	static function getHome()
	{
		var home = Sys.getEnv("AIR_HOME");
		if (home == null) throw "The environment variable AIR_HOME is not set";

		if (!msys.File.exists(home)) throw "The environment variable AIR_HOME does not point to a AIR SDK";
		return home;
	}
}