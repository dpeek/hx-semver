package mtask.core;

import mtask.core.PropertyUtil;
import Type;

#if haxe3
import haxe.ds.StringMap;
#else
private typedef StringMap<T> = Hash<T>;
#end

/**
	Loads settings from JSON files. If multiple files are specified, settings 
	are loaded in the order spcified, such that files can override earlier 
	loaded settings. This is used, for example, to allow user settings to 
	override default settings.
**/
class Settings implements PropertyResolver
{
	var data:Dynamic;
	var resolvers:StringMap<String -> Dynamic>;

	/**
		Creates a new Settings instance with no loaded values.
	**/
	public function new()
	{
		resolvers = new StringMap<String -> Dynamic>();
		data = {};
	}

	/**
		Loads the settings from the path provided, merging the properties into 
		any exiting data. The optional `key` argument allows data to be 
		merged somewhere other than the data root.
	**/
	public function load(path:String, ?key:String):Void
	{
		path = PropertyUtil.replaceTokens(path, this);
		if (!msys.File.exists(path)) return;
		
		var json = haxe.Json.parse(sys.io.File.getContent(path));
		var object = data;
		
		if (key != null)
		{
			object = get(key);
			if (object == null)
			{
				object = {};
				set(key, object);
			}

			if (Type.typeof(object) != TObject) throw "Attempted to merge '" + path + "'' settings into key '" + key + "' which contains a value.";
		}

		PropertyUtil.merge(object, json, true);
	}

	/**
		Returns a setting for the key provided. Dot notation is supported for 
		settings with fields, eg:

			settings.get("android.path")
	**/
	public function get(key:String):Dynamic
	{
		return PropertyUtil.resolve(this, key);
	}

	public function set(key:String, value:Dynamic):Void
	{
		var object = data;
		var parts = key.split(".");

		for (i in 0...parts.length - 1)
		{
			var part = parts[i];

			if (Reflect.hasField(object, part))
			{
				object = Reflect.field(object, part);
			}
			else
			{
				var tmp = object;
				object = {};
				Reflect.setField(tmp, part, object);
			}
		}

		Reflect.setField(object, parts[parts.length - 1], value);
	}
	
	public function resolve(key:String):Dynamic
	{
		var parts = key.split(".");
		var object:Dynamic = data;

		if (resolvers.exists(parts[0]))
			return new Resolver(resolvers.get(parts[0]));

		for (part in parts)
		{
			if (Reflect.hasField(object, part))
			{
				object = Reflect.field(object, part);
			}
			else
			{
				return null;
				// throw "Unable to get key '" + key + "' from settings.";
			}
		}

		return object;
	}

	public function addResolver(name:String, resolver:String -> Dynamic):Void
	{
		resolvers.set(name, resolver);
	}

	public function save(path:String):Void
	{
		msys.File.write(path, PrettyJson.stringify(data));
	}
}

class Resolver implements PropertyResolver
{
	var resolver:String -> Dynamic;

	public function new(resolver:String -> Dynamic)
	{
		this.resolver = resolver;
	}

	public function resolve(property:String):Dynamic
	{
		return resolver(property);
	}
}

class PrettyJson extends haxe.Json
{
	var depth:Int;
 
	public function new()
	{
		super();
	}
 
	#if haxe3
	override function toString(v:Dynamic, ?replacer:Dynamic -> Dynamic -> Dynamic)
	#else
	override function toString(v:Dynamic):String
	#end
	{
		this.depth = 0;
		return super.toString(v);
	}
 
	override function fieldsString(v:Dynamic, fields:Array<String>)
	{
		var first = true;
		if (buf.toString().length > 0)
		{
			buf.add("\n");
			for (i in 0...depth) buf.add('\t');
		}
		buf.add("{\n");
 
		var prev : Dynamic = null;
		depth++;
 
		for (f in fields) {
			var value = Reflect.field(v,f);
			
			if (Reflect.isFunction(value)) continue;
			if (first) first = false else buf.add(',\n');
 
			// add N=depth tabs
			for (i in 0...depth) buf.add('\t');
 
			quote(f);
			buf.add(': ');
			
			#if haxe3
			toStringRec(f, value);
			#else
			toStringRec(value);
			#end
 
			prev = value;
		}
 
		// add indented right brace
		depth--;
 
		buf.add('\n');
		for (i in 0...depth) {
			buf.add('\t');
		}
 
		buf.add('}');
		
	}
 
	public static function stringify(value:Dynamic):String
	{
		return new PrettyJson().toString(value);
	}
}
