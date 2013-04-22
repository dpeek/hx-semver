package mtask.target;

/**
The HaxeLib target compiles Haxe libraries for deployment to http://lib.haxe.org
It provides useful defaults for metadata in haxelib.xml and will optionally 
filter generated haxedoc.xml to include only the packages in your library.

The HaxeLib target will resolve templates in the following order
	
	[mtask]/resource/target/haxelib
	[project]/target/haxelib
	[project]/target/${target.id}
*/
class HaxeLib extends Target
{
	/**
	The name of the HaxeLib project, it must contain at least 3 of the 
	following allowed characters: [A-Za-z0-9_-.] (no spaces are allowed)

	This value defaults to project.id
	*/
	public var name:String;

	/**
	The URL of the projects website or respository. Please specify at 
	least the repository URL for your project, or better the home page 
	if you have any.

	This value defaults to "http://lib.haxe.org/p/${project.id}"
	*/
	public var url:String;

	/**
	Your username in the HaxeLib database. The first time the project 
	is submitted, you will be asked to register the account. Usernames 
	have the same naming rules as project names. Passwords are sent 
	encrypted (MD5) on the server and only the encrypted version is 
	stored. You can have several users for a given project if you want.

	This value defaults to user.haxelib
	*/
	public var username:String;

	/**
	The description of your project. Try to keep it small, only 2-3 sentences 
	explaining what it's doing. More information will be available on the 
	project page anyway.

	This value defaults to "Library description."
	*/
	public var description:String;

	/*
	Projects must be open source to be hosted in the central HaxeLib
	repository on lib.haxe.org

	This value defaults to MIT
	*/
	public var license:HaxeLibLicense;

	/**
	This is the information about the version you are submitting. The version 
	name must match the same naming rules as the project name.

	Thie value defaults to project.version
	*/
	public var version:String;

	/**
	A version description indicating the changes made since the last release.

	This value defaults to "Initial release."
	*/
	public var versionDescription:String;

	/**
	An array of haxelib dependencies, with optional versions. Dependencies can 
	be added by calling `addDependency(name, version)`
	*/
	var dependencies:Array<{name:String, version:Null<String>}>;

	/**
	An array of haxelib tags. See http://lib.haxe.org/ for commonly used tags.
	Tags can be added by calling `addTag(tag)`
	*/
	var tags:Array<String>;

	/**
	A generated block of Xml based on the libraries dependencies and tags.
	*/
	var block:String;
	
	public function new()
	{
		super();
		flags.push("haxelib");

		// set defaults
		name = build.env.get("project.id");
		version = build.env.get("project.version");
		username = build.env.get("haxelib.user");
		url = "http://lib.haxe.org/p/" + name;
		description = "Library description.";
		versionDescription = "Initial release.";
		license = MIT;

		// init properties
		dependencies = [];
		tags = [];
		block = "";
	}
	
	/**
	Add a library dependency with an optional version. Unversioned dependencies 
	will require the end-user have the latest version of that library installed.
	*/
	public function addDependency(name:String, ?version:String=null)
	{
		dependencies.push({name:name, version:version});
	}

	/**
	Add a library tag, allowing for easier discovery on http://lib.haxe.org
	*/
	public function addTag(name:String)
	{
		tags.push(name);
	}

	/**
	Generates the `block` value for use in the haxelib.xml template.
	*/
	override function configure()
	{
		super.configure();

		var args = [];

		// dependencies
		for (dep in dependencies)
		{
			var arg = '\n\t<depends name="' + dep.name + '"';
			
			if (dep.version != null)
			{
				arg += ' version="' + dep.version + '"';
			}
				
			arg += '/>';
			args.push(arg);
		}

		// tags
		for (tag in tags)
		{
			args.push('\n\t<tag v="' + tag + '"/>');
		}

		// build block
		block = args.join("");
	}

	override function compile()
	{
		super.compile();

		// copy the haxelib.xml to src so we can use haxelib dev if src exists
		if (exists("src")) cp(path + "/haxelib.xml", "src");
	}

	/**
		Copies LICENSE, filters docs, creates ZIP
	*/
	override function bundle()
	{
		super.bundle();
		
		// if a license is present, copy it to the haxelib
		if (exists("LICENSE"))
		{
			cp("LICENSE", path + "/LICENSE");
		}
		
		// if a haxedoc.xml is present, filter by types in the src path
		if (exists(path + "/haxedoc.xml") && exists("src"))
		{
			var filters = [];
			for (path in msys.Directory.readDirectory("src"))
			{
				if (msys.File.isDirectory("src/" + path) || StringTools.endsWith(path, ".hx"))
				{
					filters.push(path);
				}
			}
			Console.warn("filter haxedoc.xml " + filters.join(" "));
			mtask.tool.Haxe.filterXml(path + "/haxedoc.xml", filters);
		}

		// zip it good
		zip(path);
	}
}

/**
The licenses allowed by HaxeLib
*/
enum HaxeLibLicense
{
	/**
	Massachusetts Institute of Technology license
	see: http://opensource.org/licenses/mit-license.php
	*/
	MIT;

	/**
	GNU General Public License
	see: http://www.gnu.org/licenses/gpl.html
	*/
	GPL;

	/**
	GNU Lesser General Public License
	see: http://www.gnu.org/licenses/lgpl.html
	*/
	LGPL;

	/**
	Berkeley Software Distribution license
	see: http://opensource.org/licenses/bsd-license.php
	*/
	BSD;

	/**
	Public domain license
	see: http://en.wikipedia.org/wiki/Public_domain
	*/
	Public;

	/**
	Closed source license, prevents accidental submission to HaxeLib.
	*/
	Closed;
}
