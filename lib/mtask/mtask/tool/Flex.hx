package mtask.tool;

class Flex
{
	public static function fontswf(args:Array<String>)
	{
		run("fontswf", args);
	}

	static function run(tool:String, args:Array<String>)
	{
		var bin = getHome() + "/bin/" + tool;
		
		if (msys.System.isWindows)
		{
			if (msys.File.exists(bin + ".bat")) bin += ".bat";
			else if (msys.File.exists(bin + ".exe")) bin += ".exe";
			else throw "There is no windows executable for the flex tool '" + tool + "'";
		}

		mtask.core.Process.run(bin, args);
	}

	static function getHome()
	{
		var home = Sys.getEnv("FLEX_HOME");
		if (home == null) throw "The environment variable FLEX_HOME is not set";

		if (!msys.File.exists(home)) throw "The environment variable FLEX_HOME does not point to a Flex SDK";
		return home;
	}
}