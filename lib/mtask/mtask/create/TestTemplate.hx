package mtask.create;

class TestTemplate extends SourceTemplate
{
	public var forTypeName:String = "";

	public function new(type:String, path:String)
	{
		super(type, path);
		id = "test";
		if (type == "for") forTypeName = path.split(".").pop();
	}

	override function getOutputPath()
	{
		return "test/" + getTypePath();
	}

	override function getTypeID()
	{
		if (!StringTools.endsWith(path, "Test"))
		{
			return path + "Test";
		}

		return super.getTypeID();
	}
}
