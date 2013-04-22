package mtask.core;

using Lambda;
using Reflect;
import Type;

class PropertyUtil
{
	public static function merge(to:{}, from:{}, overwrite:Bool, ?dict:Dynamic):{}
	{
		for (field in from.fields())
		{
			var fromField = from.field(field);
			var toField = to.field(field);

			if (Std.is(fromField, PropertyResolver))
			{
				if (overwrite)
				{
					to.setField(field, fromField);
				}
			}
			else if (Type.typeof(fromField) == TObject)
			{
				if (Type.typeof(toField) != TObject)
				{
					if (overwrite)
					{
						toField = {};
						to.setField(field, toField);
					}
				}

				merge(toField, fromField, overwrite, dict);
			}
			else
			{
				if (dict != null)
				{
					if (Std.is(fromField, String))
					{
						var pattern = ~/^\$\{(.+?)\}$/;

						if (pattern.match(Std.string(fromField)))
						{
							fromField = resolve(dict, pattern.matched(1));

						}
						else
						{
							fromField = replaceTokens(cast(fromField, String), dict);
						}
					}
				}

				if (toField == null || overwrite)
				{
					to.setField(field, fromField);
				}
			}
		}

		return to;
	}
	
	public static function resolve(object:{}, field:String):Dynamic
	{
		var fields = field.split(".");
		
		while (fields.length > 0)
		{
			var f = fields.shift();
			if (object.hasField(f))
			{
				object = object.field(f);
			}
			else
			{
				if (Std.is(object, PropertyResolver))
				{
					var resolver = cast(object, PropertyResolver);
					object = resolver.resolve(f);
				}
				else
				{
					throw "PropertyUtil could not resolve the field: " + field;
				}
			}
		}
		
		return object;
	}
	
	public static function replaceTokens(string:String, object:{}):Dynamic
	{
		if (string == null) return "null";
		
		// dp returning correct value type for encode
		var direct = ~/^\$\{([\d\w\.]+?)\}$/;
		if (direct.match(string))
		{
			return resolve(object, direct.matched(1));
		}
		// end
		
		var pattern = ~/\$\{(.+?)\}/;
		var objectRef = object;
		
		#if haxe3
		var result = pattern.map(string, function(ereg:EReg):String
		#else
		var result = pattern.customReplace(string, function(ereg:EReg):String
		#end
		{
			var field = ereg.matched(1);
			if (field.charAt(0) == "#")
			{
				// escape
				return "${" + field.substr(1) + "}";
			}
			
			var property = resolve(objectRef, field);
			return replaceTokens(Std.string(property), objectRef);
		});
		
		return result;
	}
}

interface PropertyResolver
{
	public function resolve(property:String):Dynamic;
}
