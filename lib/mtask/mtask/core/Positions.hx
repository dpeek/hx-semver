package mtask.core;

#if macro
import haxe.macro.Type;
#elseif positions
using Lambda;
#end

#if haxe3
import haxe.ds.StringMap;
import haxe.CallStack;
#else
import haxe.Stack;
private typedef StringMap<T> = Hash<T>;
#end

class Positions
{
	#if macro

	static var added = false;

	public static function init()
	{
		if (added) return;
		added = true;
		haxe.macro.Compiler.define("positions");
		haxe.macro.Context.onGenerate(generate);
	}

	static function generate(types:Array<Type>):Void
	{
		var modules = new StringMap<Bool>();
		var lines = [];

		for (type in types)
		{
			switch (type)
			{
				case TInst(t, _):
					var type = t.get();
					var name = type.name;
					var path = type.module.split(".").join("/") + ".hx";
					path = path.split("\\").join("\\\\");

					if (modules.exists(path)) continue;
					modules.set(path, true);

					var global = haxe.macro.Context.getPosInfos(type.pos).file;
					global = global.split("\\").join("\\\\");
					
					lines.push('"' + path + '":"' + global + '"');
				default:
			}
		}

		var json = "{" + lines.join(",") + "}";
		haxe.macro.Context.addResource("map", haxe.io.Bytes.ofString(json));
	}

	#elseif positions

	static var map:StringMap<String>;

	static function getMap():StringMap<String>
	{
		if (map != null) return map;

		var resource = haxe.Resource.getString("map");
		var json = haxe.Json.parse(resource);
		var map = new StringMap<String>();

		for (field in Reflect.fields(json))
		{
			map.set(field, Reflect.field(json, field));
		}

		return map;
	}

	public static function mapStackPosition(stack:Array<StackItem>):Array<StackItem>
	{
		var map = getMap();

		return stack.map(function(item){
			return switch (item)
			{
				case FilePos(s, file, l): FilePos(s, map.exists(file) ? map.get(file) : file, l);
				default: item;
			}
		}).array();
	}

	#else

	inline public static function mapStackPosition(stack:Array<StackItem>):Array<StackItem>
	{
		return stack;
	}

	#end
}
