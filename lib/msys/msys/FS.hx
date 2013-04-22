package msys;

using Lambda;

import sys.FileSystem;
import msys.File;
import msys.Directory;

typedef FSOptions =
{
	@:optional var verbose:Bool;
	@:optional var noop:Bool;
	@:optional var preserve:Bool;
}

class FS
{
	/**
	Changes the current directory to the directory path.

	If this method is called with block, resumes to the old working directory 
	after the block execution finished.
	*/
	public static function cd(path:String, ?options:FSOptions, ?block:String -> Void):Void
	{
		Console.assert(path != null, "Cannot change directory: path is null");
		Console.assert(FileSystem.exists(path), "Cannot change directory: the path '" + path + "' does not exist");
		Console.assert(FileSystem.isDirectory(path), "Cannot change directory: the path '" + path + "' is not a directory");

		var verbose = (options != null && options.verbose == true);
		if (verbose) trace("cd " + path);

		var owd = pwd();
		Sys.setCwd(path);

		if (block != null)
		{
			block(path);
			if (verbose) trace("cd -");
			Sys.setCwd(owd);
		}
	}

	/**
	Returns the name of the current directory.
	*/
	public static function pwd():String
	{
		var path = Sys.getCwd();
		// strip trailing slash if not in root (/ or D:\)
		if (System.isWindows && path.length > 3) path = path.substr(0, -1);
		else if (path != Path.sep) path = path.substr(0, -1);
		return path;
	}

	/**
	Copies a file content src to dest. If dest is a directory, copies src to dest/src.

	If src is a list of files, then dest must be a directory.
	*/
	public static function cp(fromPath:String, toPath:String, ?options:FSOptions):Void
	{
		copyEntry(fromPath, toPath, options, false);
	}

	/**
	Copies a file content src to dest. If dest is a directory, copies src to dest/src.

	If src is a list of files, then dest must be a directory.
	*/
	public static function cp_r(fromPath:String, toPath:String, ?options:FSOptions):Void
	{
		copyEntry(fromPath, toPath, options, true);
	}

	static function copyEntry(fromPath:String, toPath:String, options:FSOptions, recursive:Bool)
	{
		Console.assert(fromPath != null, "Cannot copy files: fromPath is null");
		Console.assert(toPath != null, "Cannot copy files: toPath is null");

		var verbose = (options != null && options.verbose);
		var noop = (options != null && options.noop);
		var paths = [];

		// expand glob

		for (path in new Glob(fromPath))
		{
			if (!recursive && FileSystem.isDirectory(path))
			{
				if (verbose) trace("'" + path + "' is a directory (not copied)");
			}
			else
			{
				paths.push(path);
			}
		}
		
		if (paths.length > 1)
		{
			Console.assert(File.exists(toPath) && File.isDirectory(toPath), "Cannot copy multiple files to '" + toPath + "' because it is not a directory");
		}
		
		for (path in paths)
		{
			var targetPath = toPath;

			if (File.isDirectory(path)) // from directory
			{
				if (File.exists(toPath)) // existing
				{
					// check for file
					Console.assert(File.isDirectory(toPath), "Cannot copy '" + path + "' to '" + toPath + "' because a file exists at that path.");
					
					// to directory: toPath/basename
					targetPath = Path.join([toPath, Path.basename(path)]);
				}
				else // to path
				{
					// check parent directory exists
					var dir = Path.dirname(toPath);
					Console.assert(File.exists(dir), "Cannot copy '" + path + "' to '" + dir + "' because it does not exist");
				}
			}
			else // from file
			{
				if (File.exists(toPath))
				{
					if (File.isDirectory(toPath))
					{
						targetPath =  Path.join([toPath, Path.basename(path)]);
					}
				}
				else
				{
					// check parent directory exists
					var dir = Path.dirname(toPath);
					Console.assert(File.exists(dir), "Cannot copy '" + path + "' to '" + toPath + "' because it does not exist");
				}
			}

			if (Path.normalize(path) == Path.normalize(targetPath))
			{
				trace("'" + path + "' and '" + targetPath + "' are identical (not copied)");
			}
			else
			{
				copy(path, targetPath, verbose, noop);
			}
		}
	}

	static function copy(fromPath:String, toPath:String, verbose:Bool, noop:Bool)
	{
		if (File.isDirectory(fromPath))
		{
			if (File.exists(toPath))
			{
				Console.assert(File.isDirectory(toPath), "cannot copy a directory to '" + toPath + "' because is a file.");
			}
			else
			{
				if (!noop) Directory.create(toPath);
			}
			
			for (subPath in Directory.readDirectory(fromPath))
			{
				copy(Path.join([fromPath, subPath]), Path.join([toPath, subPath]), verbose, noop);
			}
		}
		else
		{
			if (File.exists(toPath))
			{
				Console.assert(!File.isDirectory(toPath), "cannot copy a file to '" + toPath + "' because is a directory.");
			}

			var directory = Path.dirname(toPath);
			if (!File.exists(directory) && !noop) Directory.create(directory);

			if (verbose) trace("cp " + fromPath + " -> " + toPath);
			if (!noop)
			{
				try
				{
					sys.io.File.copy(fromPath, toPath);
				}
				catch (e:Dynamic)
				{
					Console.warn("Unabled to copy file '" + fromPath + "'. It is probably a broken symlink.");
				}
			}
		}
	}

	public static function ls(?glob:String):Array<String>
	{
		if (glob == null) glob = "*";
		return new Glob(glob).array(); 
	}

	/**
	Creates a directory.
	*/
	public static function mkdir(path:String, options:FSOptions):Void
	{
		Console.assert(path != null, "Argument path cannot be null");
		Console.assert(!FileSystem.exists(path), "Cannot create directory '" + path + "': file exists!");
		
		if (options != null && options.verbose == true) trace("mkdir " + path);
		if (options != null && options.noop != true) FileSystem.createDirectory(path);
	}

	/**
	Creates a directory and all its parent directories.
	*/
	public static function mkdir_p(path:String, options:FSOptions):Void
	{
		Console.assert(path != null, "Argument path cannot be null");

		var parts = Path.split(Path.normalize(path));
		var current = [];
		var base = parts[0] == "" ? "/" : "";

		for (part in parts)
		{
			current.push(part);
			path = base + Path.join(current);
			
			if (part.length == 0) continue;
			
			if (File.exists(path))
			{
				Console.assert(File.isDirectory(path), "Cannot create directory '" + path + "': a file exists at that path");
			}
			else
			{
				if (options.verbose == true) trace("mkdir " + path);
				if (options.noop != true) FileSystem.createDirectory(path);
			}
		}
	}

	public static function rmdir(path:String, options:FSOptions):Void
	{
		Console.assert(path != null, "Argument path cannot be null");
		Console.assert(FileSystem.exists(path), "Cannot remove directory '" + path + "': file does not exist");
		Console.assert(FileSystem.isDirectory(path), "Cannot remove directory '" + path + "': file is not a directory");
		Console.assert(FileSystem.readDirectory(path).length == 0, "Cannot remove directory '" + path + "': directory is not empty");

		remove(path, options);
	}

	public static function rm(glob:String, ?options:FSOptions):Void
	{
		Console.assert(glob != null, "Argument glob cannot be null");

		for (path in new Glob(glob))
		{
			Console.assert(File.exists(path), "Cannot remove '" + path + "': the file does not exist");
			Console.assert(!FileSystem.isDirectory(path), "Cannot remove '" + path + "': file is a directory");
			remove(path, options);
		}
	}

	public static function rm_rf(path:String, ?options:FSOptions):Void
	{
		Console.assert(path != null, "Argument path cannot be null");
		if (File.exists(path)) remove(path, options);
	}

	public static function mv(glob:String):Void
	{

	}

	static function remove(path:String, options:FSOptions)
	{
		var verbose = (options != null && options.verbose == true);
		var noop = (options != null && options.noop == true);

		if (File.isDirectory(path))
		{
			for (subPath in Directory.readDirectory(path))
			{	
				subPath = Path.join([path, subPath]);
				remove(subPath, options);
			}

			if (verbose) trace("rm " + path);
			if (!noop) FileSystem.deleteDirectory(path);
		}
		else
		{
			if (verbose) trace("rm " + path);
			if (!noop) FileSystem.deleteFile(path);
		}
	}
}
