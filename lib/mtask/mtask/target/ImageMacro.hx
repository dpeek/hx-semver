package mtask.target;

import haxe.macro.Context;
import haxe.macro.Expr;

class ImageMacro
{
	public static function embed(source:String, path:String)
	{
		var pos = haxe.macro.Context.currentPos();

		if (!sys.FileSystem.exists(source))
		{
			Context.error("The path " + source + " doesn't exist!", pos);
		}

		var pack = path.split(".");
		var name = pack.pop();

		var type = {
			pos:pos,
			params:[],
			pack:pack,
			name:name,
			meta:[{pos:pos, name:":bitmap", params:[{pos:pos, expr:EConst(CString(source))}]}],
			isExtern:false,
			fields:[],
			kind:TDClass({sub:null, params:[], pack:["flash","display"], name:"BitmapData"}, [], false)
		};
		
		haxe.macro.Context.defineType(type);
	}
}