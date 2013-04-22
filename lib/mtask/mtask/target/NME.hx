package mtask.target;

import mtask.target.Target;
using Lambda;

#if haxe3
import haxe.ds.StringMap;
#else
private typedef StringMap<T> = Hash<T>;
#end

class NME extends App
{
	/**
		The target to compile (cpp, android, blackberry, cpp, flash, html5, 
		ios, webos). Defaults to cpp
	**/
	public var target:String;

	/**
		The orientation of the application: portrait, landscape or auto.
	**/
	public var orientation:Orientation;

	/**
		The main class of the application.
	**/
	var main:String;

	/**
		The block of nmml configuration to inject.
	**/
	var block:String;

	public function new()
	{
		super();
		flags.push("nme");
		target = "ios";
		block = "";
		main = "Main";
		orientation = auto;
	}

	override function processAssets(files:Array<TargetFile>)
	{
		super.processAssets(files);

		for (file in files)
		{
			var output = msys.Path.join([path, "asset", file.local]);
			var dir = msys.Path.dirname(output);
			if (!exists(dir)) mkdir(dir);
			msys.FS.cp(file.absolute, output);
		}
	}
	
	override function processHxmls(files:Array<TargetFile>)
	{
		// get haxe args
		var args = getHaxeArgs();

		// create hxml lookup
		var lookup = new StringMap<String>();
		for (file in files) lookup.set(file.local, file.absolute);

		// main hxml args
		if (lookup.exists("main.hxml"))
		{
			args = getHaxeArgsFromPath(lookup.get("main.hxml"), lookup).concat(args);
		}

		var lines = [];

		while (args.length > 0)
		{
			var arg = args.shift();
			switch (arg)
			{
				case "-main": main = args.shift();
				case "-lib", "-resource", "-D", "--macro", "-cp", "--remap":
					var value = args.shift();
					if (arg == "-cp") value = sys.FileSystem.fullPath(value);
					lines.push('<compilerflag name="' + arg + '" value="' + value + '"/>');
			}
		}
		
		// generate nmml block
		block = lines.join("\n\t");
	}

	override function compile()
	{
		super.compile();
		
		if (!exists(path + "/font")) mkdir(path + "/font");

		msys.FS.cd(path, function(path){
			cmd("haxelib", ["run", "nme"].concat(getNMEArgs("build")));
		});
	}

	override public function run()
	{
		msys.FS.cd(path, function(path){
			cmd("haxelib", ["run", "nme"].concat(getNMEArgs("run")));
		});
	}

	function getNMEArgs(command:String):Array<String>
	{
		var args = [command, "project.nmml", target];
		if (debug) args.push("-debug");
		if (debug && target == "ios") args.push("-simulator");
		if (Lambda.has(flags, "ipad")) args.push("-ipad");
		return args;
	}
}

enum Orientation
{
	auto;
	portrait;
	landscape;
}
