package mtask.target;

using Lambda;
import msys.Path;

#if haxe3
import haxe.ds.StringMap;
#else
private typedef StringMap<T> = Hash<T>;
#end

class Target extends mtask.core.Module
{
	//-------------------------------------------------------------------------- properties	

	public var plugin:Plugin;
	public var id:String;
	public var debug:Bool;
	public var haxeArgs:Array<String>;
	public var config:Dynamic;
	public var flags:Array<String>;

	/**
		Returns the path the target will be compiled to based on it's current 
		configuration options.
	**/
	public var path(get_path, null):String;
	function get_path():String
	{
		return msys.Path.join(["bin", debug ? "debug" : "release", id]);
	}

	var matchers:Array<{pattern:String, handler:Array<TargetFile> -> Void}>;

	public var beforeBuild:String -> Void;
	public var beforeCompile:String -> Void;
	public var afterCompile:String -> Void;

	public function new()
	{
		super();

		plugin = getModule(Plugin);
		debug = false;
		haxeArgs = [];
		flags = ["common"];
		config = {};
		matchers = [];

		addMatcher("\\.temp$", processTemplates);
		addMatcher("\\.hxml$", processHxmls);
	}

	function addMatcher(pattern:String, handler:Array<TargetFile> -> Void)
	{
		matchers.unshift({pattern:pattern, handler:handler});
	}

	public function executeBuild(file:String)
	{
		make();
	}

	public function addFlags(flags:Array<String>)
	{
		for (flag in flags) this.flags.push(flag);
	}

	//-------------------------------------------------------------------------- build phases

	public function make()
	{
		if (!exists(path)) mkdir(path);

		if (beforeBuild != null) beforeBuild(path);
		configure();
		if (beforeCompile != null) beforeCompile(path);
		compile();
		if (afterCompile != null) afterCompile(path);
		bundle();
	}

	function configure()
	{
		// configure target
	}

	function resolve():Array<TargetFile>
	{
		var sources = getSources();
		var files = getFiles(sources);
		return filterFiles(files);
	}

	function compile()
	{
		trace("flags: " + flags.join(","));
		
		var matched = new StringMap<Array<TargetFile>>();
		var patterns = new StringMap<EReg>();

		for (matcher in matchers)
		{
			var key = matcher.pattern;
			matched.set(key, []);
			patterns.set(key, new EReg(key, ""));
		}

		var files = resolve();
		var unmatched = [];

		if (config.v)
		{
			Console.group("target files:");
			for (file in files)
			{
				trace(file.local + " <- " + file.absolute);
			}
			Console.groupEnd();
		}
		
		for (file in files)
		{
			var isMatched = false;
			for (matcher in matchers)
			{
				var key = matcher.pattern;

				if (patterns.get(key).match(file.local))
				{
					isMatched = true;
					matched.get(key).push(file);
				}
			}
			if (!isMatched) unmatched.push(file);
		}
		
		for (matcher in matchers)
		{
			var handler = matcher.handler;
			handler(matched.get(matcher.pattern));
		}

		processUnmatched(unmatched);
	}

	function bundle()
	{
		// package into final executable
	}

	//-------------------------------------------------------------------------- run target

	public function run()
	{
		var ext = path.split(".").pop();

		switch (ext)
		{
			case "n": cmd("neko", [path]);
			case "swf", "xml", "js": openURL(path);
			case "cpp":
			default:
		}
	}

	//-------------------------------------------------------------------------- resolve files

	/**
		Returns an array of source paths for this target.
	**/
	function getSources()
	{
		var sources = [];

		var modules = getModules();
		for (module in modules)
		{
			var source = Path.join([module, "target"]);
			if (exists(source)) sources.push(source);
		}

		return sources;
	}

	/**
		Returns an array of paths to search for modules.
	**/
	function getModuleSources():Array<String>
	{
		var paths = [];
		paths.push(replaceArgs("${lib.mtask}module"));
		for (plugin in build.plugins)
		{
			var path = replaceArgs("${lib." + plugin + "}module");
			if (exists(path)) paths.push(path);
		}
		paths.push(sys.FileSystem.fullPath("target"));
		return paths;
	}

	/**
		Returns an array of modules paths for this target by searching module 
		paths for modules matching each flag in flags.
	**/
	function getModules():Array<String>
	{
		var modules = [];

		// get paths to search for modules
		var modulePaths = getModuleSources();

		// for each flag, check module paths for module
		for (modulePath in modulePaths)
		{
			for (flag in flags)
			{
				var module = Path.join([modulePath, flag]);
				if (exists(module)) modules.push(module);
			}
		}

		return modules;
	}

	/**
		Returns an array of TargetFiles from an array of sources by executing 
		a recursive glob in each directory. TargetFiles describe both the 
		absolute and local (relative to the source) path of the file.
	**/
	function getFiles(sources:Array<String>):Array<TargetFile>
	{
		var files = [];
		
		sources = sources.copy();
		sources.reverse();

		for (source in sources)
		{
			for (absolute in msys.FS.ls(source + "/**/*.*"))
			{
				var local = absolute.substr(source.length + 1);
				files.push({absolute:absolute, local:local});
			}
		}

		return files;
	}

	/**
		Filters an array of TargetFiles based on the targets flags. The rules 
		for this filtering operation are:

		1) if a directory name contains flags (somedir@foo@bar) and ANY of those 
		   flags is not in the target flags, all files in that directory are 
		   filtered out.
		2) a file with no flag is assigned a priotity of 0
		3) a file with a flag is assigned a priority of flags.indexOf(flag)
		4) if multiple versions of a file exist (same local path), the result 
		   is decided on priority, then on order (first wins)
	**/
	function filterFiles(files:Array<TargetFile>):Array<TargetFile>
	{
		var flagRe = ~/@(\w+)/g;
		var filtered = [];
		var priorities = new StringMap<{file:TargetFile, priority:Int}>();

		var lookup = new Hash<Array<TargetFile>>();

		for (file in files)
		{
			// if has flag not in target flags, filter
			var exit = false;
			var hasFlag = flagRe.match(file.local);
			while (hasFlag)
			{
				if (flags.indexOf(flagRe.matched(1)) == -1)
				{
					exit = true;
					break;
				}
				hasFlag = flagRe.match(flagRe.matchedRight());
			}
			if (exit) continue;

			// the local path of the file (without flags)
			var local = flagRe.replace(file.local, "");

			// add file to lookup
			if (lookup.exists(local)) lookup.get(local).push(file);
			else lookup.set(local, [file]);
		}

		for (local in lookup.keys())
		{
			var files = lookup.get(local);

			if (files.length > 1)
			{
				files.sort(function(a,b){
					var aParts = Path.split(a.local);
					var bParts = Path.split(b.local);
					
					for (i in 0...aParts.length)
					{
						var aPriority = -1;
						var bPriority = -1;

						if (flagRe.match(aParts[i]))
						{
							aPriority = flags.indexOf(flagRe.matched(1));
						}

						if (flagRe.match(bParts[i]))
						{
							bPriority = flags.indexOf(flagRe.matched(1));
						}

						if (aPriority != bPriority)
						{
							return bPriority - aPriority;
						}
					}
					return 0;
				});

				if (config.v)
				{
					Console.group("priority: " + local);
					for (file in files) trace(file.absolute);
					Console.groupEnd();
				}
			}

			// first file is the winner
			var file = files[0];
			file.local = local;
			filtered.push(file);
		}

		// sorting makes it easier to spot issues
		filtered.sort(function(a,b){return Reflect.compare(b.local, a.local); });

		return filtered;
	}

	//-------------------------------------------------------------------------- process hxml
	
	/**
		Builds any haxe targets within the target.
	**/
	function processHxmls(files:Array<TargetFile>)
	{
		// create hxml lookup
		var lookup = new StringMap<String>();
		for (file in files) lookup.set(file.local, file.absolute);

		for (file in files)
		{
			if (!~/\.\w+\.hxml$/.match(file.local)) continue;

			// determine output path
			var output = Path.join([path, file.local.substr(0, -5)]);

			// check directory exists
			var dir = msys.Path.dirname(output);
			if (!exists(dir)) msys.FS.mkdir_p(dir, {});

			// build target
			buildHaxe(file.absolute, output, lookup);
		}
	}

	/**
		Builds a Haxe target by reading args from path, adding additional args 
		from target, replacing any arg tokens with properties from target and 
		invoking the Haxe compiler.
	**/
	function buildHaxe(fromPath:String, toPath:String, ?lookup:StringMap<String>):Void
	{
		// determine platform
		var ext = toPath.split(".").pop();
		if (ext == "n") ext = "neko";

		// add platform to args
		var args = ["-" + ext, toPath];

		// add hxml args
		for (arg in getHaxeArgsFromPath(fromPath, lookup)) args.push(arg);

		// add target args
		for (arg in getHaxeArgs()) args.push(arg);

		// replace any tokens
		for (i in 0...args.length) args[i] = replaceArgs(args[i], this);

		// execute build
		try
		{
			mtask.core.Process.run("haxe", args);
		}
		catch (e:mtask.core.Error)
		{
			Console.error(e.toString(), []);
			throw e;
		}
	}

	/**
		Returns an array of Haxe compiler args from an hxml file at path. Any 
		hxml files referenced in the file are located using `lookup`, and then 
		inserted into the resulting args by recursively calling getHaxeArgs.
	**/
	function getHaxeArgsFromPath(path:String, lookup:StringMap<String>):Array<String>
	{
		var args = [];
		
		for (line in msys.File.read(path).split("\n"))
		{
			// skip comments
			if (line.charAt(0) == "#") continue;

			// skip empty lines
			if (StringTools.trim(line) == "") continue;

			// process args
			for (arg in line.split(" "))
			{
				arg = StringTools.trim(arg);
				
				// resolve hxml path
				if (StringTools.endsWith(arg, ".hxml"))
				{
					// locate the referenced hxml file
					var path = lookup.get(arg);
					for (arg in getHaxeArgsFromPath(path, lookup)) args.push(arg);
				}
				else
				{
					// add raw arg
					args.push(arg);	
				}
			}
		}

		return args;
	}

	/**
		This method supplies additional arguments to pass to the haxe compiler 
		for each hxml sub-target. It can be overridden by subclasses to provide 
		additional customisation.
	**/
	function getHaxeArgs():Array<String>
	{
		var args = haxeArgs.concat([]);
		if (debug) args.push("-debug");

		if (config.flags != null)
		{
			var flags = Std.string(config.flags).split(",");
			for (flag in flags)
			{
				args.push("-D");
				args.push(flag);
			}
		}

		for (module in getModules())
		{
			var path = msys.Path.normalize(replaceArgs(module) + "/src");
			
			if (exists(path))
			{
				args.push("-cp");
				args.push(path);
			}
		}

		return args;
	}

	//-------------------------------------------------------------------------- process templates

	/**
		Builds a targets templates by reading from path, replacing tokens with 
		properties from target and writing to path.
	**/
	function processTemplates(files:Array<TargetFile>)
	{
		for (file in files)
		{
			// determine output path
			var output = Path.join([path, file.local.substr(0, -5)]);
			
			// check directory exists
			var dir = msys.Path.dirname(output);
			if (!exists(dir)) msys.FS.mkdir_p(dir, {});

			// read template
			var content = read(file.absolute);

			// replace tokens
			content = replaceArgs(content, this);

			// write to path
			write(output, content);
		}
	}

	//-------------------------------------------------------------------------- process unmatched

	/**
		Processes any any unmatched files by copying them into the target.
	**/
	function processUnmatched(files:Array<TargetFile>)
	{
		for (file in files)
		{
			var output = Path.join([path, file.local]);
			var dir = msys.Path.dirname(output);
			if (!exists(dir)) msys.FS.mkdir_p(dir, {});
			msys.FS.cp(file.absolute, output);
		}
	}

	/**
		A helper function for ignoring matched target files.
	**/
	function processIgnore(files:Array<TargetFile>)
	{
		// ignore
	}
}

typedef TargetFile =
{
	absolute:String,
	local:String
}
