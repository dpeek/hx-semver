package mtask.create;

class Template extends mtask.core.Module
{
	public var id:String;
	public var type:String;
	public var path:String;

	public function new(id:String, type:String, path:String)
	{
		super();

		this.id = id;
		this.type = type;
		this.path = path;
	}

	/**
		Compiles the template.
	**/
	public function compile()
	{
		// abstract
	}

	/**
		Returns the path the template will read from.
	**/
	function getTemplatePath():String
	{
		return getModule(Plugin).getTemplatePath(id, type);
	}

	/**
		Returns the path that the template will write to.
	**/
	function getOutputPath():String
	{
		return path;
	}
}

class File extends Template
{
	public function new(template:String, type:String, path:String)
	{
		super(template, type, path);
	}
	
	override public function compile()
	{
		// create the containing directory if it doesn't exist
		var output = getOutputPath();
		var dir = msys.Path.dirname(output);
		if (!exists(dir)) mkdir(dir);

		// write content to output
		write(output, getContent());
	}

	/**
		Returns the content that will be written to the output path.
	**/
	function getContent():String
	{
		return replaceArgs(getTemplate(), this);
	}

	/**
		Returns the template for the file, which will have tokens replaced with 
		properties and be written to the output path.
	**/
	function getTemplate():String
	{
		return read(getTemplatePath());
	}
}

class Directory extends Template
{
	public function new(template:String, type:String, path:String)
	{
		super(template, type, path);
	}

	override function compile()
	{
		cp(getTemplatePath(), getOutputPath());
	}
}
