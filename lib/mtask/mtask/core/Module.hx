package mtask.core;

/**
	Module defines the base functionality of an mtask module. It provides the 
	contextual information tasks need to execute, as well as a number of 
	frequently used task file system commands (exists, rm, mkdir, etc...)
**/
@:autoBuild(mtask.core.ModuleMacro.build())
class Module
{
	/**
		The current build instance
	**/
	public static var main(default, null):Build;

	/**
		The current build instance
	**/
	public var build(default, null):Build;

	/**
		An array of tasks belonging to this module
	**/
	public var tasks(default, null):Array<Task>;

	/**
		The name of the module, displayed when listing help
	**/
	public var moduleName(default, null):String;

	/**
		Private Module constructor. Modules should extend this base class.
	**/
	function new()
	{
		tasks = [];
		if (main != null) build = main;
		var className = Type.getClassName(Type.getClass(this));
		moduleName = className.split(".").pop().toLowerCase();
	}

	/**
		Replaces the tokens in `string` with properties from `args`. If `args` 
		are not specified, `build.env` is used.
	**/
	function replaceArgs(string:String, ?args:Dynamic=null):String
	{
		if (args == null) args = this.build.env;
		return PropertyUtil.replaceTokens(string, args);
	}
	
	/**
		Returns a singleton instance of the module for this build, 
		instantiating and adding it if it has not yet been requested.
	**/
	public function getModule<T>(type:Class<T>):T
	{
		return build.getModule(type);
	}
	
	/**
		Invokes a task that matches the provided argument string, throwing an 
		exception if none is found.
	**/
	public function invoke(task:String)
	{
		build.invoke(task);
	}

	/**
		An abstract method that is called by `BuildCore` on each loaded module 
		when a new module is added.
	**/
	public function moduleAdded(module:Module)
	{
		// abstract
	}

	//-------------------------------------------------------------------------- utils

	/**
		Checks if a file of directory exists at `path`
	**/
	function exists(path:String):Bool
	{
		return msys.File.exists(replaceArgs(path));
	}

	/**
		Move the file at `fromPath` to `toPath`
	**/
	function mv(fromPath:String, toPath:String)
	{
		fromPath = replaceArgs(fromPath);
		toPath = replaceArgs(toPath);

		Console.info("move " + fromPath + " -> " + toPath);
		msys.File.move(fromPath, toPath);
	}

	/**
		Write `content` to the file at `path`
	**/
	function write(path:String, content:String)
	{
		path = replaceArgs(path);
		Console.info("write " + path);
		msys.File.write(path, content);
	}

	/**
		Replaces the tokens in the file at `path` with the properties found in 
		`args`. See `doc/tokens.md` for more information.
	**/
	function template(path:String, ?args:Dynamic=null)
	{
		path = replaceArgs(path);
		if (args == null) args = build.env;

		Console.info("template " + path);
		write(path, replaceArgs(read(path), args));
	}

	/**
		Read the content from the file at `path`
	**/
	function read(path:String):String
	{
		return msys.File.read(replaceArgs(path));
	}

	/**
		Create a zip archive from the directory at `fromPath` to either 
		`toPath` or `fromPath + ".zip"`
	**/
	function zip(fromPath:String, ?toPath:String, ?includeDirectory:Bool=false)
	{
		if (toPath == null) toPath = fromPath + ".zip";
		fromPath = replaceArgs(fromPath);
		toPath = replaceArgs(toPath);

		Console.info("zip " + fromPath + " -> " + toPath);
		msys.Directory.zip(fromPath, toPath, includeDirectory);
	}

	/**
		Executes a shell command with the provided arguments, returning stdout 
		if the program exits with 0, or stderr otherwise.
	**/
	function cmd(command:String, args:Array<String>):String
	{
		command = replaceArgs(command);
		for (i in 0...args.length) args[i] = replaceArgs(args[i]);
		
		try
		{
			return mtask.core.Process.run(replaceArgs(command), args);
		}
		catch (e:Error)
		{
			Console.error(e.toString(), []);
			throw e;
		}

		return null;
	}

	/**
		Copies files or directories from one path to another.
	**/
	function cp(fromPath:String, toPath:String):Void
	{
		fromPath = replaceArgs(fromPath);
		toPath = replaceArgs(toPath);
		Console.info("cp " + fromPath + " " + toPath);
		msys.FS.cp_r(fromPath, toPath);
	}

	/**
		Creates a directory at the provided path if one does not exist, 
		creating any intermediate paths do not exist. This command is 
		equivalent to the shell command `mkdir -p`
	**/
	function mkdir(path:String):Void
	{
		path = replaceArgs(path);
		if (exists(path) && msys.File.isDirectory(path)) return;

		Console.info("mkdir " + path);
		msys.FS.mkdir_p(path, {});
	}

	/**
		Removes a path if it exists. Warning: this command is equivalent to the 
		shell command `rm -rf` and will cause damage if you ask it to.
	**/
	function rm(path:String)
	{
		path = replaceArgs(path);
		if (!exists(path)) return;

		Console.info("rm " + path);
		msys.FS.rm_rf(path);
	}

	/**
		Open a path using the system editor for that type. This will open URLs 
		in a browser, and other files in an editor.
	**/
	function open(path:String)
	{
		path = replaceArgs(path);
		try
		{
			msys.Process.open(path);
		}
		catch (e:Dynamic)
		{
			Console.error("Failed to open '" + path + "', possibly becuase there is no default editor set?", []);
		}
	}

	/**
		Open a local URL in the default browser. If user.localhost_root is set 
		and the file is located under it then the URL will be opened in 
		localhost. If not the URL is opened as a file:///
	**/
	function openURL(path:String)
	{
		path = sys.FileSystem.fullPath(path);
		
		var root = build.env.get("localhost.root");

		if (root == "" || !StringTools.startsWith(path, root))
		{
			if (root == "") Console.warn("Set localhost.root to open URLs in your localhost");
			else Console.warn("Unable to open URL in localhost as it is not under user.localhost_root");

			if (msys.File.isDirectory(path)) path += "/index.html";
			path = "file://" + path;
		}
		else
		{
			path = build.env.get("localhost.url") + path.substring(root.length);
		}

		open(path);
	}
}
