package mtask.target;

import msys.Path;
import mtask.target.Target;

#if haxe3
import haxe.ds.StringMap;
#else
private typedef StringMap<T> = Hash<T>;
#end

class App extends Target
{
	public var params:Dynamic;
	public var title:String;
	public var background:Int;
	public var width:Int;
	public var height:Int;

	var browser:Bool;
	var backgroundHex:String;

	public function new()
	{
		super();
		
		flags.push("app");
		params = {};
		title = build.env.get("project.name");
		background = 0xAFAEB3;
		width = 0;
		height = 0;
		browser = false;

		addMatcher("^asset.+(png|jpg)$", processAssets);
		addMatcher("^asset.+xml$", processIgnore);
	}

	override function configure()
	{
		super.configure();

		browser = (config.browser == true);
		backgroundHex = StringTools.lpad(StringTools.hex(background), "0", 6);

		params.target = flags[flags.length - 1];
		params.width = width;
		params.height = height;
		params.app = replaceArgs("${project.id}-${project.version}");
		params.build = replaceArgs("${user.name} " + Date.now().toString());
		
		write(".temp/mtask/params.json", haxe.Json.stringify(params));
	}

	function processAssets(files:Array<TargetFile>)
	{
		var libraries = new StringMap<Array<TargetFile>>();

		for (file in files)
		{
			var parts = Path.split(file.local);
			parts.shift(); // assets

			var id = parts.shift();
			file.local = parts.join("/");

			var images = [];
			if (libraries.exists(id)) images = libraries.get(id);
			else libraries.set(id, images);
			images.push(file);
		}

		for (id in libraries.keys())
		{
			processAssetLibrary(id, libraries.get(id));
		}
	}

	function processAssetLibrary(id:String, files:Array<TargetFile>)
	{
		var images = [];

		for (file in files)
		{
			var body = "/>";
			var size = ImageUtil.getSize(file.absolute);

			// check for additional image metadata
			var metaPath = file.absolute.split(".")[0] + ".xml";
			if (exists(metaPath))
			{
				var xml = Xml.parse(read(metaPath)).firstElement().firstElement();
				body = ">"+xml.toString().split("\n").join("").split("\t").join("")+"</image>";
			}

			var image = '<image uri="'+file.local+'" width="'+size.width+'" height="'+size.height+'"'+body;
			images.push(image);
		}

		var meta = '<assets>'+images.join("")+'</assets>';
		if (!exists(path + "/asset")) mkdir(path + "/asset");
		write(path + "/asset/"+id+".xml", meta);
	}

	override function getHaxeArgs():Array<String>
	{
		var args = super.getHaxeArgs();
		
		// add flag for each device flag
		for (flag in flags)
		{
			args.push("-D");
			args.push(flag);
		}
		
		if (browser)
		{
			args.push("-D");
			args.push("browser");
		}

		// add params resource
		args.push("-resource");
		args.push(sys.FileSystem.fullPath(".temp/mtask/params.json@params"));

		// configure mpartial
		if (mtask.tool.HaxeLib.isInstalled("mpartial"))
		{
			args.push("-lib");
			args.push("mpartial");

			args.push("--macro");
			args.push("mpartial.PartialsMacro.append(['" + flags.join("','") + "'])");
		}
		
		return args;
	}
}
