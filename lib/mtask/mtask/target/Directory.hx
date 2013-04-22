package mtask.target;

class Directory extends Target
{
	public function new()
	{
		super();
	}

	override function compile()
	{
		zip(path);
	}
}
