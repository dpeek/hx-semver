System
====================

## RunLoop

For platforms with no native run-loop (cpp, neko, php) this offers a basic implementation, supporting 
the processing of active mcore.util.Timer's and the ability to alter frame rate.

> Note: This requires mcore.util.Timer from the `mcore` haxelib

#### Example Usage:

Create a run-loop at the start of your application and set its dynamic *initialize* method with your 
start-up method.

	import m.sys.RunLoop;
	import mcore.util.Timer;

	class Application
	{
		public static function main()
		{
			new Application();
		}
				
		public function new()
		{
			// Note that if you're not under cpp, neko or php this code will simply call start with no other side effects
			RunLoop.primary.frameRate = 20; // 20 ticks per second
			RunLoop.primary.initialize = start;
			RunLoop.primary.run();
		}
		
		function start()
		{
			trace("starting application");

			// You can then use the Timer class as you would in a js or flash app.
			Timer.runOnce(function() { trace("Timer executed"); }, 1000);
		}
	}
