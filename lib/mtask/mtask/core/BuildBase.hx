package mtask.core;

/**
	BuildBase defines a standard set of modules for use in mtask builds. It 
	should not be instantiated directly, rather extended by a projects main 
	Build class.
**/
class BuildBase extends BuildCore
{
	/**
		A boolean indicating if the current build is a project, or a global 
		build. A project is detected by the presence of a project.json file.
	**/
	public var isProject(default, null):Bool;
	
	/**
		BuildBase should not be instantiated directly, it should be subclassed 
		by your projects Build class.
	**/
	function new()
	{
		super();
		
		// detect project
		isProject = exists("project.json");

		// add environment resolvers
		env.addResolver("lib", mtask.tool.HaxeLib.getLibraryPath);
		env.addResolver("sys", Sys.getEnv);
		env.addResolver("mtask", resolveArg);

		// load environment
		env.load("${lib.mtask}config.json");
		env.load("${mtask.home}config.json");

		// add core modules
		getModule(Setup);
		getModule(Help);

		if (isProject)
		{
			// create working dir
			if (!exists(".temp/mtask")) mkdir(".temp/mtask");

			// backwards compatability
			var settings = new Settings();
			settings.load("project.json");
			if (settings.get("project") == null) 
				untyped env.data.project = settings.data;
			else env.load("project.json");
			
			// user settings
			env.load("user.json");
			getModule(mtask.target.Plugin);
		}

		getModule(mtask.create.Plugin);
		loadPlugins();
		addModule(this);
	}

	function resolveArg(arg:String):Dynamic
	{
		return switch (arg)
		{
			case "home": msys.Path.join([msys.System.userDirectory, ".mtask/"]);
			case "project": 
				var project = new Settings();
				project.addResolver("lib", mtask.tool.HaxeLib.getLibraryPath);
				project.load("${lib.mtask}../project.json");
				return project.get("project");
			default: null;
		}
	}

	override function loadPlugins()
	{
		// macro generated method
	}
}
