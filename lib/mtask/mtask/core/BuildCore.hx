package mtask.core;

import mtask.core.PropertyUtil;

/**
	BuildCore defined the standard functionality of an mtask build. It provides 
	methods for adding and retriving modules, 
**/
#if haxe3
class BuildCore extends Module implements PropertyResolver
#else
class BuildCore extends Module, implements PropertyResolver
#end
{
	/**
		The build environment
	**/
	public var env(default, null):Settings;

	/**
		The modules that have been added to the build
	**/
	public var modules(default, null):Array<Module>;

	/**
		An instance of OptionParser used parse task options
	**/
	public var options(default, null):OptionParser;

	/**
		An array of loaded plugin ids
	**/
	public var plugins(default, null):Array<String>;

	/**
		BuildCore should not be instantiated directly, it should be subclassed 
		by your projects Build class.
	**/
	function new()
	{
		super();

		if (!Std.is(this, Build)) throw "Build must be Build!";
		untyped Module.main = build = this;

		// create env
		env = new Settings();

		// create lists
		modules = [];
		plugins = [];
		
		// create option parser
		options = new OptionParser();

		// initialise console printer
		var printer = Console.defaultPrinter;
		printer.printPosition = false;
		printer.printLineNumbers = false;
		printer.colorize = true;
		Console.start();
	}

	/**
		Adds a module to the build. Checks for `@task` metadata on the modules 
		instance fields, creating new tasks for each. Once added, `moduleAdded` 
		is invoked on all modules to give them an opportunity to react to new 
		modules (eg. the target module checks new modules for @target meta).
	**/
	function addModule(module:Module)
	{
		modules.push(cast module);
		
		var typeMeta = haxe.rtti.Meta.getFields(Type.getClass(module));
		
		for (field in Reflect.fields(typeMeta))
		{
			var meta = Reflect.field(typeMeta, field);
			
			if (Reflect.hasField(meta, "task"))
			{
				var task = new Task(module, field);
				module.tasks[Std.parseInt(meta.index[0])] = task;
			}
		}

		for (m in modules) m.moduleAdded(module);
	}

	/**
		Returns a singleton instance of the module for this build, 
		instantiating and adding it if it has not yet been requested.
	**/
	override public function getModule<T>(type:Class<T>):T
	{
		for (module in modules)
		{
			if (Std.is(module, type))
			{
				return cast module;
			}
		}

		var module = Type.createInstance(type, []);
		addModule(cast module);
		return module;
	}

	/**
		Invokes a task that matches the provided argument string, throwing an 
		exception if none is found.
	**/
	override public function invoke(args:String)
	{
		var match = getTask(args);

		if (match == null)
		{
			throw new Error("No task matches '" + args + "'");
		}
		else
		{
			match.invoke(args);
		}
	}

	/**
		Returns the task that matches the given args by calling `match(args)` 
		on each available task. Returns null if no matching task is found.
	**/
	public function getTask(args:String):Task
	{
		for (module in modules)
		{
			for (task in module.tasks)
			{
				var id = args.split(" ")[0];
				if (id == task.id) return task;
			}
		}

		return null;
	}
	
	/**
		Resolve properties for replaceArgs
	**/
	public function resolve(property:String):Dynamic
	{
		return env.get(property);
	}

	function loadPlugins()
	{
		// macro generated method
	}
}
