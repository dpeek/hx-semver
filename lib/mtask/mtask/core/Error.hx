package mtask.core;

#if haxe3
import haxe.CallStack;
#else
import haxe.Stack;
#end

class Error
{
	var message:String;
	var stack:Array<StackItem>;

	public function new(message:String, ?stack:Array<StackItem>)
	{
		if (stack == null) stack = [];
		this.message = message;
		this.stack = stack;
	}
	
	public function toString()
	{
		return message;
	}
}
