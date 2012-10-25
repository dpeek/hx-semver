import mtask.target.HaxeLib;

class Build extends mtask.core.BuildBase
{
	public function new()
	{
		super();
	}

	@target function haxelib(t:HaxeLib)
	{
		t.beforeCompile = function(path)
		{
			cp("src/*", path);
		}
	}

	@task function sublime()
	{
		invoke("run main.n");
	}
}
