package mtask.create;

class SourceTemplate extends Template.File
{
	/**
		The class documentation block.
	**/
	public var docBlock:String = "";

	/**
		The license block, or an empty string.
	**/
	public var licenseBlock:String = "";

	/**
		The full type id: com.example.Example
	**/
	public var typeID:String = "";

	/**
		The type name: Example
	**/
	public var typeName:String = "";

	/**
		The type package: com.example
		(or an empty string if none)
	**/
	public var packageName:String = "";

	/**
		The package block, or an empty string if no package.
	**/
	public var packageBlock:String = "";

	public function new(type:String, path:String)
	{
		super("source", type, path);

		// generate doc block
		docBlock = "/**\n\t@author " + build.env.get("user.name") + "\n**/\n";

		// generate license block
		if (exists("LICENSE"))
		{
			licenseBlock = "/*\n" + StringTools.trim(read("LICENSE")) + "\n*/\n\n";
		}

		// generate type id
		typeID = getTypeID();
		var parts = typeID.split(".");
		typeName = parts.pop();
		packageName = parts.join(".");

		// generate package block
		if (packageName != "")
		{
			packageBlock = "package " + packageName + ";\n\n";
		}
	}

	function getTypeID()
	{
		return path;
	}

	function getTypePath()
	{
		return getTypeID().split(".").join("/") + ".hx";
	}

	override function getOutputPath()
	{
		return "src/" + getTypePath();
	}
}
