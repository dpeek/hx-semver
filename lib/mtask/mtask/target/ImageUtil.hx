package mtask.target;

class ImageUtil
{
	public static function getSize(path:String):{width:Int, height:Int}
	{
		var bytes = sys.io.File.getBytes(path);
		var ext = path.split(".").pop();
		var b = bytes.get;
		
		// TODO: Should not really look at physical extension as often misleading. ms 30.12.11
		// check that a jpg is not actually a png (seems to occur quite often)
		if (ext == "jpg" && b(0) == 0x89 && b(1) == 0x50 && b(2) == 0x4E)
			ext = "png";
		
		switch (ext)
		{
			case "jpg":				
				if (b(0) == 0xFF && b(1) == 0xD8 && b(2) == 0xFF)
				{
					var i = 4;
					var s = bytes.readString;
					var l = bytes.length;

					var type = s(i+2,1) + s(i+3,1) + s(i+4,1) + s(i+5,1);	
					if (((b(i-1) == 0xE0 && type == "JFIF") || (b(i-1) == 0xE1 && type == "Exif")) && b(i+6) == 0x00)
					{
						var block = b(i) * 256 + b(i+1);

						while (i < l)
						{
							// Increase the file index to get to the next block
							i += block;

							// Check for end of file
							if (i > l) throw "EOF";

							// Check that we are truly at the start of another block
							if (b(i) != 0xFF) throw "Not really a block!";
							
							// 0xFFC0 is the "Start of frame" marker which contains the file size
							// 0xFFC0 == baseline
							// 0xFFC2 == progressive
							if (b(i+1) == 0xC0 || b(i+1) == 0xC2)
							{            
								//The structure of the 0xFFC0 block is quite simple [0xFFC0][ushort length][uchar precision][ushort x][ushort y]
								var height = b(i+5) * 256 + b(i+6);
								var width = b(i+7) * 256 + b(i+8);
								return {width:width, height:height};
							}
							else
							{
								// skip to next block marker
								i += 2;

								//Go to the next block
								block = b(i) * 256 + b(i+1);
							}
						}
					}
				}

			case "png":
				var input = new haxe.io.BytesInput(bytes);
				var reader = new format.png.Reader(input);
				
				for (chunk in reader.read())
				{
					switch (chunk)
					{
						case CHeader(h):
						return {width:h.width, height:h.height};
						default:
					}	
				}

			default:
		}
		
		return {width:0, height:0};
	}
}
