# Development Workflow

Automating developer workflow is a challenge common to all languages and 
platforms. As the develop, compile, deploy, test cycle is central to the work 
both developers and designers undertake, gains in efficiency can have a 
profound impact on productivity and general well-being. On top of this, 
knowledge and experience can be shared between development teams in the form 
of powerful, reusable tasks, reducing the siloing of platform expertise.

There are many solutions to the developer workflow problem; Make, Ant, Maven, 
Rake, Grunt to name but a few; but none that met the very unique requirements 
of a multi-platform SDK. Massive Task is a bespoke solution to the complexities 
of compiling native applications for a huge number of devices from a single 
code base.

## How it Works

Using mtask developers can define development tasks in Haxe. Similar to Ruby 
Rake, this has the advantage of providing developers with an expressive DSL for 
defining tasks in the same language that they use to build applications.

When invoked, mtask compiles a project specific Neko executable and invokes it 
with the arguments provided on the command line. This allows developers to 
leverage both the [Neko API](http://haxe.org/api/neko/) and 
[Neko libraries](http://lib.haxe.org/t/neko) as a base for tasks.

## Tasks

Creating a task is as simple as marking a module method with the @task metadata:

	@task function test(?foo:Bool)
	{
		trace(foo);
	}

Which can be invoked from the command line with:

	$ haxelib run mtask test -foo

	true

For more information on tasks, see [working with tasks](doc/tasks.md) and 
[working with options](doc/options.md).

## Targets

Mtask provides powerful mechanism for defining compilation targets that strikes 
a careful balance between convenience and configuration. For more information 
see [working with targets](doc/targets.md)

## Extending

Mtask also provides extensibility and configuration hooks, allowing developers 
to share plugins and development resources and settings between projects and 
libraries. For more information see [working with configuration](doc/config.md) 
and [working with plugins](doc/plugins.md).
