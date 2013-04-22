## Tasks

A task is a unit of work in MTask. Tasks are defined by adding `@task` 
metadata to any a module method. Simple string parameters are automatically 
parsed from the arguments passed to the build.

### Using Tasks

To execute a task from the command line, simply execute:

	$ mtask [task] [?arguments]

All core functionality in mtask is implemented as tasks:

	$ mtask create source class HelloWorld
	        [task] [      arguments      ]

You can print all available tasks, along with short descriptiong for each by
executing:

	$ mtask help

You can print documentation for a task by executing:

	$ mtask help [task]


### Creating Tasks

In a module, add a task using the `@task` metadata:

	@task function sleep()
	{
		trace("Sleeping...");
	}

By default, the name of the task is the method name. You can change this 
default by passing a custom name to `@task`

	@task("sleep") function commenceSleeping()
	{
		trace("Sleeping...");
	}

You can use javadoc style comments to add documentation to your task:
	
	/**
		Sends build system to sleep.

		When the build system is tired and cranky sometimes what it needs is a 
		good long nap.
	**/
	@task function sleep()
	{
		trace("Hello from foo!");
	}

The first line of the docs will appear when `help` is run:
	
	$ mtask help
	  [...]
	  sleep  Sends build system to sleep.

Additional docs are avaiable using `help task`:

	$ mtask help sleep
	Sends build system to sleep.

	When the build system is tired and cranky sometimes what it needs is a 
	good long nap.

### Arguments

To allow users to pass additional configuration to your task, you can specify 
String arguments for the task method:

	@task function sleep(hours:String)
	{
		trace("Sleeping for " + hours + " hours.");
	}

Optional arguments allow users to optionally specify a value:

	@task function sleep(?hours:String)
	{
		if (hours == null) trace("Sleeping for 8 hours.");
		else trace("Sleeping for " + hours + " hours.");
	}

> Version 1.3 introduced more advanced option parsing for tasks. See 
> doc/options.md for more information.

### Dependencies

To execute one task from another, call invoke:

	invoke("sleep 8");

