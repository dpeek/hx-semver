## Templates

MTask provides a simple, flexible mechanism for generating files and directory 
structures from predefined templates. The library includes templates for 
generating projects, source code, unit tests and licenses. It is also possible 
for users, and other libraries to provide additional templates to mtask 
through the same mechanism.


### Using Templates

To create a file or directory from a template, user the create task:

	mtask create project neko HelloWorld

The create task takes three arguments:

	mtask create [template] [type] [path]

The **template** argument indicates the type of template to create, for example a 
project, source file, unit test or license. Templates share a common set of 
arguments that can be inserted into generated files, as well as custom 
behavior based on type and path.

To get a list of available templates, execute:

	mtask list:template

The **type** argument indicates the type of a particular template to create. When 
creating a project, for example, type will create a project configured for a 
particular target workflow – a library, a simple neko program or a dual target 
javascript/flash project:

	mtask create project neko NekoProject
	mtask create project haxelib LibraryProject

To get a list of available template (in this case license) types, execute:

	mtask list:template license

The **path** argument controls the output location of the template. In some cases 
this will be a file path, in others it might be an identifier for the file to 
create. When creating source files, for example, the path is the name of the 
class to create:

	mtask create source class com.example.Example


#### Project Template Types

MTask includes a number of project templates for different targets. Note that 
the initial type of project does not prevent you from adding more targets 
later in development.

* neko - simple neko target suitable for a command line tool, web app or quick 
  test case
* haxelib - haxelib target and munit test suite, providing a quick starting 
  point for a library
* app - a dual flash/js target UI application
* empty - an empty mtask project


#### Source and Test Template Types

MTask provides a convenient mechanism for generating templated source files. 
Source files are generated in the `src` directory, and any package directories 
are created as needed. If a `LICENSE` file is found in the root of the current 
project, it is added to the top of the class as a license header. JavaDoc 
style author metadata is also added based on the value of `user.name`.

To create an empty class:

	mtask create source class com.example.MyInstance

To create a class with a main entry point:

	mtask create source main com.example.Main

There are also templates for munit test classes, which are created in the 
`test` directory:

	mtask create test class com.example.MyTest

To create a test for an instantiatable class, use the `for` type. A test class 
will be created with predefined `setup` and `tearDown` methods creating and 
destroying an instance of the class under test:

	mtask create test for com.example.MyInstance

(this will create a test named com.example.MyInstanceTest)


#### License Types

MTask provides several license templates to quickly create a project license 
with correct `year` and `user.organization` values.

	mtask create license (bsd|mit|gpl|lgpl) LICENSE


### Creating Template Types

It is simple to add an additional type to an existing template. When creating a 
template, the `Create` module resolves the path to copy in the following way:

	[path]/[template]/[type]

The default path is:

	[mtask]/resource/create/

You can add search paths for a project, library, or globally using the 
following:

	module(mtask.create.Create).addTemplatePath("another/path");

For more information about configuring mtask see [configuring MTask](TODO).


### Creating New Templates

To create a new template for a project or library you should subclass 
`mtask.create.Template.File` or `mtask.create.Template.Directory` and register 
the template with the `Create` module:

	module(mtask.create.Create).addTemplate("changelog", ChangeLogTemplate)

Templates are modules and have access to the build environment and properties. 
They configure properties and their output path, resolve the template to copy, 
and then copy it to the path. `File` templates replace tokens with properties:

	class Greeter extends mtask.create.Template.File
	{
		public var noun:String;

		public function new(type:String, path:String)
		{
			super("template", type, path)
			noun = "World";
		}
	}

And the template file:

	Hello ${noun}

Would generate:

	Hello World

`Directory` templates will only replace tokens in files with the extension 
`.temp` (which is removed when copying).
