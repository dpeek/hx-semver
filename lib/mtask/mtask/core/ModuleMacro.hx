package mtask.core;

import haxe.macro.Expr;
import haxe.macro.Type;
using Lambda;

/**
	The ModuleMacro.build macro adds additional metadata to Module fields 
	marked with either @task or @target metadata. This metadata is used by 
	the build system to automatically create `Task` and `Target` instances 
	from each field.

	It also detects @plugin metadata on modules, adding the plugin path to the 
	classPath and generating the loadPlugins method that adds each plugin 
	module to the build on startup.
**/
class ModuleMacro
{
	static var plugins = [];

	/**
		Adds additional metadata to module fields.
	**/
	#if haxe3 macro #else @:macro #end
	public static function build():Array<Field>
	{
		// remove when switching to haxe 3, as -D absolute-path does the same
		Positions.init();
		
		var pos = haxe.macro.Context.currentPos();
		var fields = haxe.macro.Context.getBuildFields();
		var taskIndex = 0;

		// Look for @plugin metadata on Build classes
		var local = haxe.macro.Context.getLocalClass();
		if (local != null)
		{
			var localClass = local.get();
			var localName = localClass.pack.concat([localClass.name]).join(".");

			if (localName == "Build")
			{
				if (sys.FileSystem.exists("build/User.hx"))
				{
					// load user module if there is one
					plugins.push("getModule(User);");
				}

				if (plugins.length > 0)
				{
					// generate loadPlugins
					fields.push({pos:pos, name:"loadPlugins", meta:[], doc:null, access:[AOverride], kind:FFun(
						{ret:null, params:[], args:[], expr:haxe.macro.Context.parse("{super.loadPlugins();" + plugins.join("") + "}", pos)}
					)});
				}
			}
		}

		for (field in fields)
		{
			switch (field.kind)
			{
				case FFun(f):
				for (meta in field.meta)
				{
					switch (meta.name)
					{
						// add @options and @man metadata to tasks
						case "task":
							if (field.doc != null)
							{
								var doc = StringTools.trim(field.doc.split("\t").join(""));
								doc = doc.split('"').join('\\"');
								var man = haxe.macro.Context.parse('"' + doc + '"', pos);
								field.meta.push({pos:pos, params:[man], name:"man"});
							}

							field.meta.push({pos:pos, params:[{pos:pos, expr:EConst(CString(Std.string(taskIndex)))}], name:"index"});

							var opts = {pos:pos, params:[], name:"options"};
							field.meta.push(opts);

							for (arg in f.args)
							{
								var type = getTypeName(arg.type);
								var expr = haxe.macro.Context.parse("{name:'" + arg.name + "',type:'" + type + "',optional:" + arg.opt + ",defaultValue:" + getDefaultValue(type, arg.value) + "}", pos);
								opts.params.push(expr);
							}
							
							taskIndex += 1;
						
						// add @args metdata to targets
						case "target":
							if (f.args.length < 1) haxe.macro.Context.error("@target must specify a Target type as the first argument", field.pos);
							var type = f.args[0].type;
							var args = {pos:pos, params:[], name:"args"};
							field.meta.push(args);
							
							switch (type)
							{
								case TPath(path):
								var type = haxe.macro.Context.getType(path.pack.concat([path.name]).join("."));
								switch (type)
								{
									case TInst(t, _):
									var ctype = t.get();
									var name = ctype.pack.join(".") + "." + ctype.name;
									args.params.push({pos:pos, expr:EConst(CString(name))});
									
									default:
								}

								default:
							}
					}
				}

				default:
			}
		}

		return fields;
	}

	#if haxe3 macro #else @:macro #end
	public static function addPlugins():Array<Field>
	{
		var env = new mtask.core.Settings();
		env.addResolver("lib", mtask.tool.HaxeLib.getLibraryPath);
		var home = msys.System.userDirectory + "/.mtask";
		env.load(home + "/config.json");
		env.load("project.json");
		env.load("user.json");
		var obj = env.get("plugin");
		for (plugin in Reflect.fields(obj))
		{
			if (Reflect.field(obj, plugin) != "1") continue;
			var path = mtask.tool.HaxeLib.getLibraryPath(plugin);
			if (path == null)
			{
				Sys.println("The plugin " + plugin + " could not be found. Please run `haxelib install " + plugin + "`");
			}
			else
			{
				plugins.push("getModule(mtask." + plugin + ".Plugin);");
				plugins.push("plugins.push('" + plugin + "');");
				haxe.macro.Compiler.addClassPath(path);
			}
		}

		return haxe.macro.Context.getBuildFields();
	}

	//-------------------------------------------------------------------------- helper methods

	static function getDefaultValue(type:String, expr:Expr):String
	{
		if (expr != null)
		{
			return switch (expr.expr)
			{
				case EConst(c):
					switch (c)
					{
						case CString(s): "'" + s + "'";
						case CInt(v): Std.string(v);
						case CFloat(f): Std.string(f);
						default: "null";
					}
				default: "null";
			}
		}

		return switch (type)
		{
			case "Int": "0";
			case "Float": "0.0";
			case "Bool": "false";
			case "String": "null";
			default: "null";
		}
	}

	static function getName(type:Type):String
	{
		if (type == null) return "";
		
		return switch (type)
		{
			case TInst(t, params):
				var p = "";
				if (params.length > 0)
					p = "<" + params.map(getName).array().join(",") + ">";
				if (p == "<>") p = "";
				var type = t.get();
				type.pack.concat([type.name]).join(".") + p;
			case TEnum(t, _):
				var type = t.get();
				type.pack.concat([type.name]).join(".");
			case TAbstract(t, _):
				var type = t.get();
				type.pack.concat([type.name]).join(".");
			case TMono(t):
				getName(t.get());
				
			default:
				"Dynamic";
		}
	}

	static function getTypeName(type:Null<ComplexType>):String
	{
		if (type == null) return "Dynamic";
		

		switch (type)
		{
			case TPath(p):
				
				var params = "";
				if (p.params.length > 0)
					params = "<" + p.params.map(getTypeParamName).array().join(",") + ">";
				var path = p.pack.concat([p.name]).join(".");
				
				try
				{
					var type = haxe.macro.Context.getType(path + params);
					return getName(type);
				}
				catch (e:Dynamic)
				{
					return path + params;
				}
				
			default:
				return "Dynamic";
		}
	}

	static function getTypeParamName(param:TypeParam):String
	{
		return switch (param)
		{
			case TPType(t): getTypeName(t);
			default: "Dynamic";
		}
	}
}
