package mtask.tool;

import msys.File;
import mtask.core.Process;

class HaxeLib
{
	//-------------------------------------------------------------------------- public

	public static function getRepositoryPath():String
	{
		if (repositoryPath == null) repositoryPath = pathWithTrailingSlash(Process.run("haxelib", ["config"], false));
		return repositoryPath;
	}

	public static function getLibraryPath(lib:String):Null<String>
	{
		var libPath = getRepositoryPath() + lib + "/";
		if (!File.exists(libPath)) return null;

		if (File.exists(libPath + ".dev")) libPath = msys.File.read(libPath + ".dev");
		else libPath = libPath + File.read(libPath + ".current") + "/";
		return pathWithTrailingSlash(libPath);
	}

	public static function isInstalled(lib:String, ?version:String):Bool
	{
		var path = getLibraryPath(lib);
		if (path == null) return false;
		if (version == null) return true;
		if (msys.File.exists(path + version.split(".").join(","))) return true;
		return false;
	}

	public static function require(lib:String, ?version:String):Void
	{
		if (!isInstalled(lib, version)) install(lib, version);
		if (version != null) set(lib, version);
	}

	public static function install(lib:String, ?version:String):Void
	{
		if (version == null) cmd(["install", lib]);
		else cmd(["install", lib, version]);
	}

	public static function dev(lib:String, path:String):Void
	{
		if (path != getLibraryPath(lib)) cmd(["dev", lib, path]);
	}

	public static function run(lib:String, args:Array<String>):Void
	{
		require(lib);
		cmd(["run", lib].concat(args));
	}

	public static function git(lib:String, url:String, ?dir:String):Void
	{
		if (dir != null) cmd(["git", lib, url, dir]);
		else cmd(["git", lib, url]);
	}

	public static function test(path:String):Void
	{
		cmd(["test", path]);
	}

	public static function remove(lib:String):Void
	{
		if (isInstalled(lib)) cmd(["remove", lib]);
	}

	public static function set(lib:String, version:String)
	{
		if (isInstalled(lib)) cmd(["set", lib, version]);
	}

	//-------------------------------------------------------------------------- private

	static var repositoryPath:String;

	static function cmd(args:Array<String>):Void
	{
		Process.run("haxelib", args);
	}

	static function pathWithTrailingSlash(path:String):String
	{
		if (path.charAt(path.length - 1) != "/") return path + "/";
		return path;
	}
}
