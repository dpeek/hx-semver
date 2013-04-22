package msys;

import msys.File;

#if sys

import sys.FileSystem;
import sys.io.FileOutput;

#elseif neko

import neko.Sys;
import neko.FileSystem;
import neko.io.FileOutput;

#elseif cpp

import neko.Sys;
import neko.FileSystem;
import neko.io.FileOutput;

#end

#if haxe3
import haxe.zip.Writer;
import haxe.zip.Entry;
#else
import format.zip.Writer;
import format.zip.Data;
#end

import haxe.io.Bytes;
using msys.File;
using mcore.util.Arrays;

class Directory
{
	public static function glob(pattern:String):Glob
	{
		return new Glob(pattern);
	}
	
	/**
	Check if a directory is empty

	@param path 	existing directory path
	@return true if directory is empty
	*/
	public static function isEmpty(path:String):Bool
	{
		Console.assert(path != null, "the argument 'path' cannot be null");
		Console.assert(path.isDirectory(), "the path '" + path + "' is not a directory and cannot be read.");
		return readDirectory(path).length == 0;
	}

	/**
	Create a directory at path. Directories are created recursively, so that 
	any intermediate directories are created as well.
	*/
	public static function create(path:String)
	{	
		Console.assert(path != null, "the argument 'path' cannot be null");
		
		var parts = Path.split(path);
		var current = [];
		var base = (parts[0] == "" ? "/" : "");

		for (part in parts)
		{
			current.push(part);
			path = base + Path.join(current);
			if (part.length == 0) continue;
			
			if (path.exists())
			{
				Console.assert(path.isDirectory(), "the path " + path + " is not a directory");
			}
			else
			{
				FileSystem.createDirectory(path);
			}
		}
	}

	/**
	Deletes the file or directory at path.
	@param path 	file or directory to remove
	@param pathFilter 	optional regexp filter (defaults to none)
	*/
	public static function removeTree(path:String)
	{
		Console.assert(path != null, "the argument 'path' cannot be null");
		path = File.nativePath(path);
		
		if (!path.exists()) return;

		Console.assert(path.isDirectory(), "the path '" + path + "' is not a directory");

		for (subPath in readDirectory(path))
		{	
			subPath = File.append(path,subPath);

			if (subPath.isDirectory())
			{
				removeTree(subPath);
			}
			else
			{
				subPath.remove();
			}
		}

		path.remove();
	}

	/**
	Returns an array of strings naming the files and directories in the directory
	denoted by the path.
	
	@param path 	directory
	@return array of strings naming the files in the path
	*/
	public static function readDirectory(path:String):Array<String>
	{
		Console.assert(path != null, "the argument 'path' cannot be null");
		path = path.nativePath();

		Console.assert(path.exists(), "the path '" + path + "' does not exist");
		Console.assert(path.isDirectory(), "the path '" + path + "' is not a directory");

		var filenames = [];
		for (filename in FileSystem.readDirectory(path))
		{
			filenames.push(filename);
		}
		return filenames;
	}

	public static function zip(fromPath:String, toPath:String, ?includeDirectory:Bool=true)
	{
		Console.assert(fromPath != null, "the argument 'fromPath' cannot be null");
		Console.assert(toPath != null, "the argument 'toPath' cannot be null");

		Console.assert(fromPath.exists(), "fromPath '" + fromPath + "' doesnt not exist");
		Console.assert(fromPath.isDirectory(), "fromPath '" + fromPath + "' is not a directory");

		fromPath = sys.FileSystem.fullPath(fromPath);

		var parent = fromPath.parent();
		var folder = fromPath.filename(); 
		var file = toPath.filename();

		var cwd = Sys.getCwd();
		Sys.setCwd(parent);

		// if (System.isWindows)
		// {
			try
			{
				var entries:List<Entry> = getZipEntries(folder, includeDirectory);		
				var zip = NativeFile.write(file, true);
				
				var writer = new Writer(zip);
				#if haxe3
				writer.write(entries);
				#else
				writer.writeData(entries);
				#end

				zip.close();

				Sys.setCwd(cwd);
				file = parent + "/" + file;

				if (!file.equals(toPath))
				{
					file.move(toPath);
				}
			}
			catch(e:Dynamic)
			{
				Sys.setCwd(cwd);
				throw e;
			}
		// }
		// else
		// {
		// 	// mac/linux only, much faster
		// 	Sys.command("zip", ["-rq", file, folder]);
		// 	Sys.setCwd(cwd);
		// }
	}

	static function getZipEntries(fromPath:String, ?includeDirectory:Bool=true):List<Entry>
	{
		Console.assert(fromPath != null, "the argument 'fromPath' cannot be null");

		fromPath = fromPath.nativePath();
		var files = new Glob(fromPath + "/**/*");
		var list:List<Entry> = new List();

		for (file in files)
		{
			var filename = Path.normalize(file);
			
			if (!includeDirectory)
			{
				var filesInPath = filename.split(Path.sep);
				
				if (filesInPath.length > 1)
				{
					var folder = filesInPath.shift();					
				}
				
				filename = filesInPath.join(Path.sep);
			}
			
			if (FileSystem.isDirectory(file)) continue;
			var bytes = NativeFile.getBytes(file);
			
			#if haxe3
			var crc32 = haxe.crypto.Crc32.make(bytes);
			#else
			var crc32 = format.tools.CRC32.encode(bytes);
			#end

			var entry = {
				fileName:filename,
				fileSize:bytes.length,
				fileTime:Date.now(),
				data:bytes,
				compressed:false,
				dataSize:0,
				crc32:crc32,
				extraFields:new List()
			};
			
			list.push(entry);
		}
		
		return list;
	}
}
