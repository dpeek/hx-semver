package mtask.core;

#if haxe3
import haxe.ds.StringMap;
#else
private typedef StringMap<T> = Hash<T>;
#end

/**
	A task option definition.
**/
typedef Option = {name:String, type:String, optional:Bool, defaultValue:Dynamic};

/**
	OptionParser parses a string into an array of arguments for a task method 
	based on an array of options.
**/
class OptionParser
{
	/**
		A Hash of named type resolvers. To add a resolver, call `addType`
	**/
	var resolvers:StringMap<String -> Dynamic>;

	/**
		Creates a new OptionParser instance
	**/
	public function new()
	{
		resolvers = new StringMap<String -> Dynamic>();
	}

	/**
		Parses a string command into an array of arguments for a task.
	**/
	public function parse(command:String, options:Array<Option>):Array<Dynamic>
	{
		var args = command.split(" ");
		var id = args.shift();
		var hash = new StringMap<Dynamic>();
		var strings = [];

		while (args.length > 0)
		{
			var arg = args.shift();

			if (arg.charAt(0) == "-")
			{
				var field = arg.substr(1, arg.length - 1);
				
				if (args.length > 0 && args[0].charAt(0) != "-")
				{
					hash.set(field, args.shift());
				}
				else
				{
					hash.set(field, true);
				}
			}
			else
			{
				strings.push(arg);
			}
		}

		var args:Array<Dynamic> = [];

		for (option in options)
		{
			var name = option.name;
			var value:Dynamic;

			if (hash.exists(name))
			{
				value = hash.get(name);
				hash.remove(name);
			}
			else
			{
				value = strings.shift();
			}

			if (value == null)
			{
				if (option.optional)
				{
					value = option.defaultValue;
				}
				else
				{
					error("The task " + id + " requires the option -" + option.name);
				}
			}
			
			trace("options type " + option.type + " val:" + value);

			switch (option.type)
			{
				case "String":
					if (value != null && !Std.is(value, String))
						error("The option -" + name + " should be of type String " + value);

				case "Bool":
					if (Std.is(value, String))
					{
						if (value == "true" || value == "false" || value == "1" || value == "0")
							value = (value == "true" || value == "1");
						else
							error("The option -" + name + " should be of type Bool " + value);
					}
				case "Int":
					if (Std.is(value, String)) value = Std.parseFloat(value);
					if (Math.isNaN(value)|| value % 1 != 0) error("The option -" + name + " " + value + " should be of type Int");
				case "Float":
					if (Std.is(value, String)) value = Std.parseFloat(value);
					if (Math.isNaN(value)) error("The option -" + name + " " + value + " should be of type Int");
				
				case "Array<String>":
					if (value != null)
						value = value.split(",");

				case "Array<Int>":
					if (value != null)
					{
						value = value.split(",");
						for (i in 0...value.length) value[i] = Std.parseInt(value[i]);
					}
					
				case "Array<Float>":
					if (value != null)
					{
						value = value.split(",");
						for (i in 0...value.length) value[i] = Std.parseFloat(value[i]);
					}
					
				case "Dynamic":
					if (name == "rest")
					{
						value = {};
						for (key in hash.keys())
						{
							Reflect.setField(value, key, hash.get(key));
							hash.remove(key);
						}
					}
				
				default:
					if (Std.is(value, String))
					{
						var resolved = resolveType(option.type, value);
						if (resolved == null) error("Could not resolve type " + option.type + " from string " + value);
						else value = resolved;
					}
			}

			args.push(value);
		}

		for (key in hash.keys())
			error("Unknown option '" + key + "' for task '" + id + "'");
		for (string in strings)
			error("Unknown option '" + string + "' for task '" + id + "'");

		return args;
	}

	public function addType<T>(type:Class<T>, resolver:String -> T):Void
	{
		resolvers.set(Type.getClassName(type), resolver);
	}

	function resolveType(type:String, arg:String):Dynamic
	{
		if (resolvers.exists(type)) return resolvers.get(type)(arg);
		
		var typeClass = Type.resolveClass(type);
		if (typeClass != null)
		{
			var typeSuper = Type.getSuperClass(typeClass);
			while (typeSuper != null)
			{
				var nameSuper = Type.getClassName(typeSuper);
				if (resolvers.exists(nameSuper))
				{
					var resolved = resolvers.get(nameSuper)(arg);
					if (Std.is(resolved, typeClass)) return resolved;
					else
					{
						var msg = "Resolved option was of incorrect type '" + Type.getClassName(Type.getClass(resolved)) + "', task expected '" + Type.getClassName(typeClass) + "'";
						throw new Error(msg);
					}
				}
				typeSuper = Type.getSuperClass(typeSuper);
			}
		}

		return null;
	}

	function error(message:String)
	{
		throw new Error(message);
	}
}
