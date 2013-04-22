package mtask.core;

class REPL
{
	var position:Int = -1;
	var input:String = "";
	var history:Array<String>;
	var onExecute:Array<String> -> Void;

	public var onCompletion:String -> String;

	public function new(onExecute:Array<String> -> Void)
	{
		this.onExecute = onExecute;

		// input character
		history = [];
		Sys.print("< ");

		while (true)
		{
			var char = Sys.getChar(false);
			
			switch (char)
			{
				case 27: arrow();
				case 127: backspace();
				case 9: tab();
				case 3: break;
				case 13:
					Sys.print("\n");
					if (input == "x") break;
					enter();
				default: 
					Sys.print(String.fromCharCode(char));
					input += String.fromCharCode(char);
			}
		}
	}

	function arrow()
	{
		if (Sys.getChar(false) == 91)
		{
			var char = Sys.getChar(false);

			if (char ==  65 || char == 66) // up/down
			{
				var index = char == 65 ? position + 1 : position - 1;
				if (index > -1 && index < history.length)
				{
					position = index;

					for (i in 0...input.length) backspace();
					input = history[position];
					Sys.print(input);
				}
				else
				{
					bell();
				}
			}
		}
	}

	function backspace()
	{
		if (input.length > 0)
		{
			Sys.stdout().writeByte(0x08);
			Sys.stdout().writeString(" ");
			Sys.stdout().writeByte(0x08);
			input = input.substr(0, -1);
		}
	}

	function tab()
	{
		if (onCompletion != null)
		{
			var completion = onCompletion(input);

			if (completion == null)
			{
				bell();
			}
			else
			{
				Sys.print(completion.substr(input.length));
				input = completion + " ";
			}
		}
		else
		{
			bell();
		}
	}

	function enter()
	{
		if (input == "" && history.length > 0)
		{
			input = history[0];
		}
		else
		{
			history = history.slice(position + 1);
			history.unshift(input);
		}
		
		onExecute(input.split(" "));
		Sys.print("< ");
		input = "";
		position = -1;
	}
	
	function bell()
	{
		Sys.stdout().writeByte(0x07);
	}
}
