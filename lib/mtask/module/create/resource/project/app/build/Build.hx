class Build extends mtask.core.BuildBase
{
	public function new()
	{
		super();
	}
	
	@task function launch()
	{
		invoke("run flash");
		invoke("run web");
	}

	@task function test()
	{
		mtask.tool.HaxeLib.run("munit", ["test", "-coverage"]);
	}
}
