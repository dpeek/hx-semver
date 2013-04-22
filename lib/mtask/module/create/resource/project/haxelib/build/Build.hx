import mtask.target.HaxeLib;

class Build extends mtask.core.BuildBase
{
	public function new()
	{
		super();
	}

	@target function haxelib(t:HaxeLib)
	{
		t.description = "A description of your library.";
		t.versionDescription = "Initial release.";
		
		// t.addDependency("library");

		t.afterCompile = function(path)
		{
			cp("src/*", path);
		}
	}

	@task function test()
	{
		mtask.tool.HaxeLib.run("munit", ["test", "-coverage"]);
	}

	@task function release()
	{
		invoke("clean");
		invoke("build haxelib");
		invoke("test");
	}
}
