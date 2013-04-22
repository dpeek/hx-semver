## Options

Starting in mtask 1.3, tasks can now accept a wider range of options from the 
command line. The changes are backwards compatible, and allow for far more 
felixable configuration of tasks from the commandline.

### Previous limitations

The original task invokation approach limited task arguments to a simple array 
of strings that corresponded to the task arguments. Arguments could be 
optional, in which case they would be passed as `null` during invocation.

	@task function foo(bar:String, ?baz:String):Void {}

	$ mtask foo bing
	$ mtask foo bing bang

While the approach was flexible enough to facility custom option parsing, it 
resulted in some boiler in user defined tasks.

### New Option Parsing

The new invokation approach allows for much more flexible and predictable 
configuration on tasks.

	@task function foo(bar:String, ?baz:Int, ?quux:Bool, rest:Dynamic)
	{
		Sys.println("bar: " + bar);
		Sys.println("baz: " + baz);
		Sys.println("quux: " + quux);
		Sys.println("rest: " + rest);
	}

Can be called in the following ways:

	$ mtask foo bing

	bar: bing
	baz: 0
	quux: false
	rest: {}

	$ mtask foo bing -baz 10

	bar: bing
	baz: 10
	quux: false
	rest: {}

	$ mtask foo bing -quux

	bar: bing
	baz: 0
	quux: true
	rest: {}

	$ mtask foo bing -something

	bar: bing
	baz: 0
	quux: false
	rest: { something:true }

### Option Types

Option parsing supports the following option types:

	Int				-flag 1
	Float			-flag 1.3
	String			-flag foo
	Array<Int>		-flag 1,2,3
	Array<Float>	-flag 1.1,1.2,3
	Array<String>	-flag foo,bar,baz

An option named `rest` of type `Dynamic` will capture any addtional options 
passed to a task:

	@task function foo(?rest:Dynamic)
	{
		trace(rest);
	}

	// ...

	$ mtask foo -arg1 hello -arg2 -arg3 world
	{ arg1:"hello", arg2:true, arg3:"world" }

### Custom Type Parsing

Sometimes it might be desirable to pass custom types to tasks without having to 
resolve from a simple type (string or int) to a complex type. This can be 
accomplished in mtask by registering a type resolver with the build option 
parser:

	build.options.addType(MyType, function(value:String){ return new MyType(); })

When a complex type is found in the options of a task, the option parser checks 
for a registered resolver for the type, walking the inheritance chain in case 
the option type is a subclass of a mapped resolver. If a resolver is found, it 
is invoked with the string value of the option as an argument. The resolver 
function is responsible for finding the correct value.

This mechanism is used by the `build` task to resolve the `target` option:

	build.options.addType(Target, function(id:String){
		return getTarget(id);
	});

	// ...

	@task function build(target:Target, ?debug:Bool, ?rest:Dynamic)
	{
		// ...
	}
