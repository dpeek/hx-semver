package mtask.tool;

import mtwin.net.Ftp;

class FTP
{
	public static function connect(server:String, username:String, password:String):FTP
	{
		return new FTP(server, username, password);
	}

	var connection:Ftp;

	function new(server:String, username:String, password:String)
	{
		connection = new Ftp(server);
		connection.login(username, password);
	}
	
	public function put(localPath:String, remotePath:String)
	{
		if (msys.File.isDirectory(localPath))
		{
			try { removeDirectory(remotePath, connection); } catch (e:Dynamic){}
		}
		else
		{
			try { connection.deleteFile(remotePath); } catch (e:Dynamic){}
		}
		
		putRecursive(localPath, remotePath, connection);
	}
	
	public function get(localPath:String, remotePath:String)
	{
		if (connection.fileSize(remotePath) > 0)
		{
			var file = neko.io.File.write(localPath, true);
			connection.get(file, remotePath);
			file.close();
		}
	}

	public function close():Void
	{
		connection.close();
	}
	
	function putRecursive(localPath:String, remotePath:String, connection:Ftp)
	{
		if (msys.File.isDirectory(localPath))
		{
			connection.createDirectory(remotePath);
			
			for (file in msys.Directory.readDirectory(localPath))
			{
				putRecursive(localPath + "/" + file, remotePath + "/" + file, connection);
			}
		}
		else
		{
			Console.info("ftp put " + localPath + " -> " + remotePath);
			var file = neko.io.File.read(localPath, true);
			connection.put(file, remotePath);
			file.close();
		}
	}
	
	function removeDirectory(path:String, connection:Ftp)
	{
		var list = connection.detailedList(path);
		
		for (item in list)
		{
			var file = item.split(" ").pop();
			
			if (item.charAt(0) == "d")
			{
				removeDirectory(path + "/" + file, connection);
			}
			else
			{
				connection.deleteFile(path + "/" + file);
			}
		}
		
		connection.removeDirectory(path);
	}
}