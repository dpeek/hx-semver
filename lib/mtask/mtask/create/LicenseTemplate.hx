package mtask.create;

class LicenseTemplate extends Template.File
{
	public var year:Int;
	public var organization:String;

	public function new(type:String, path:String)
	{
		super("license", type, path);
		
		year = Date.now().getFullYear();
		organization = build.env.get("user.organization");
	}
}
