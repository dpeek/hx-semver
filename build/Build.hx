class Build extends mtask.core.BuildBase
{
	public function new()
	{
		super();
	}

	@task function sublime()
	{
		invoke("run main.n");
	}
}
