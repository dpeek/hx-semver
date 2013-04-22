## Plugins

Plugins are designed to allow exensibility of the mtask build environment. As 
most mtask functionality is built on demand, this generally involves modifying 
the classpath of the the compiled build, and adding modules to the core build 
using a macro-generated initialisation method.

To add a plugin to your build, add a `plugin` object to your `project.json`

	{
		"plugin": 
		{
			"munit": "1"
		}
	}

Note plugins can be configured in project, user and global config. To disable a 
global/user plugin, override the plugin setting to `"0"` in your `project.json`

The field name should correspond to an installed haxelib. During compilation of 
the build, the path of each plugin library is added to the mtask build path.
In addition to this, the macro system defines a `loadPlugins` method that adds 
a `Plugin` module from each defined plugin. The generated method looks like 
this:

	override function loadPlugins()
	{
		super.loadPlugins();
		getModule(mtask.munit.Plugin);
		getModule(mtask.create.Plugin);
	}

For a HaxeLib to be used as an mtask plugin, you must define a class in your 
library named `mtask.{library name}.Plugin` that extends `mtask.core.Module`.

Here is an example plugin module:

	package mtask.munit;

	class Plugin extends mtask.core.Module
	{
		public function new()
		{
			super();

			// set custom module name
			moduleName = "munit";

			// configure build in some way
			getModule(mtask.create.Plugin).addTemplatePath("${lib.mui}resource/create");
		}

		@task function test()
		{
			// run an munit test
		}
	}
