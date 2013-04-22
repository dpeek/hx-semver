package msys;

import mcore.util.Timer;

#if (haxe_208 && (cpp || neko || php))
typedef Sys =
	#if cpp
	cpp.Sys;
	#elseif neko
	neko.Sys;
	#elseif php
	php.Sys;
	#end
#end

/**
 * Simple application run loop which iterates at a defined frame rate and checks whether
 * any pending mcore.util.Timer instances need to be processed.
 *
 * This is targeted at applications with no graphics based UI e.g. command line interface.
 *
 * To use, set your application entry method to RunLoop.primary.initialize and then call run.
 *
 * e.g.
 *
 *		RunLoop.primary.frameRate = 18;
 *		RunLoop.primary.initialize = startApp;
 *		RunLoop.primary.run();
 *
 * Note that if you're not under cpp, neko or php targets then the above code will just
 * call startApp with no other side effects.
 *
 * To exit your application either call:
 *
 *		RunLoop.primary.exit() // passing an optional exit code,
 *
 * or call exit directly:
 *
 *		Sys.exit();
 *
 * Again if you're not under cpp, neko or php this will have no effect.
 *
 * If for whatever reason you just want to stop the loop without exiting.
 *
 *		RunLoop.primary.stop();
 */
class RunLoop
{
	// NOTE: Considered using neko.vm.Ui run loop for neko but our RunLoop
	//		 is really just meant for simple none ui based apps.

	public static inline var DEFAULT_FRAMERATE:Int = 10;

	/**
	 * Returns the primary run loop.
	 */
	public static var primary(get_primary, null):RunLoop;
	static function get_primary()
	{
		if (primary == null)
			primary = new RunLoop();
		return primary;
	}

	/**
	 * Number of iterations per second. Defaults to 10.
	 */
	#if haxe3
	@:isVar 
	#end
	public var frameRate(get_frameRate, set_frameRate):Null<Int>;

	/**
	 * Returns true once run() has been called.
	 */
	public var running(default, null):Bool;

	var interval:Float;

	public function new()
	{
		frameRate = DEFAULT_FRAMERATE;
	}

	function get_frameRate():Null<Int>
	{
		return frameRate;
	}

	function set_frameRate(value:Null<Int>):Null<Int>
	{
		if (value == null || value < 1)
			throw new mcore.exception.ArgumentException("Frame rate cannot be less than 1 but was [" + value + "]");

		interval = 1 / value;
		return frameRate = value;
	}

	/**
	 * Start the run loop.
	 */
	public function run()
	{
		if (running)
			return;

		running = true;

		#if (!nme && (cpp || neko || php || java || cs))
		Timer.activate();
		#end

		initialize();

		#if (!nme && (cpp || neko || php || java || cs))
		do
		{
			Timer.tick();
			update();
			Sys.sleep(interval);
		}
		while (running);
		#end
	}

	/**
	 * Set this dynamic function with your application entry function.
	 * It will be called once when run() is called.
	 */
	dynamic public function initialize()
	{}

	/**
	 * Assign if you have custom logic to be run each frame.
	 */
	dynamic public function update()
	{}

	/**
	 * Stops the run loop but does not exit the application.
	 */
	public function stop()
	{
		running = false;
	}

	/**
	 * Exit the run loop and your application. Equivalent to calling Sys.exit().
	 *
	 * Under JS and Flash plugin the application will not be exited.
	 */
	public function exit(?code:Int = 0)
	{
		running = false;
		#if (cpp || neko || php || java || cs)

		Sys.exit(code);

		#elseif flash

		try {
			flash.system.FSCommand._fscommand("quit", "");
		}
		catch(e:Dynamic) {}

		#end
	}
}
