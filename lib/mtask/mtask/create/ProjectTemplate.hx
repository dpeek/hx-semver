package mtask.create;

class ProjectTemplate extends Template.Directory
{
	public function new(type:String, path:String)
	{
		super("project", type, path);
	}
}
