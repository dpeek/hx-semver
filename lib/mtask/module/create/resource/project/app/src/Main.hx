class Main
{
	public static function main()
	{
		#if !munit
		// initialize console
		Console.start();
		var console = new mconsole.ConsoleView();
		console.attach();
		Console.addPrinter(console);
		#end

		trace("Hello World!");
		return true;
	}
}
