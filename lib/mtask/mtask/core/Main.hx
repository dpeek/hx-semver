package mtask.core;

/**
	The main entry point for a build. Generally builds are executed by the 
	build runner (run.n) which loads compiled builds as a neko module and 
	executes the exported `run` method.

	To create stand alone mtask programs that do not require the runner, define 
	the compiler flag "runner". This will invoke the build in the main entry 
	point rather than relying on the runner to do so.
**/
@:build(mtask.core.ModuleMacro.addPlugins())
class Main
{
	static function __init__()
	{
		neko.vm.Module.local().setExport("run", mtask.core.Main.run);
	}

	/**
		Invokes the build when in "runner" mode
	**/
	public static function main()
	{
		#if runner
		run(Run.getArgs().join(" "));
		#end
	}

	/**
		Exported method called by build runner to invoke a build task
	**/
	public static function run(args:String)
	{
		new Build().invoke(Std.string(args));
	}
}
