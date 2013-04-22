System IO
====================

## File and Directory

A slightly more forgiving and full featured API for working with files and directories.
Some methods are simply wrappers for Haxe API methods, others are error checking and 
additional features like recursive operations.

These APIs are designed to simplify working with paths across multiple operating systems (Win, OSX, Linux) by normalising pathing to a unix style prior to manipulation.


#### Example Usage:

The API is pretty self explanatory. Simply call the static methods to work with files:

	File.copy("my-file.txt", "my-file.txt.bak");
	File.exists("my-file.txt");
	File.parent("src/my-file.txt");


The API has also been designed to work nicely with `using`

	using m.sys.io.File;
	...

	var path = "resources/my-file.txt";

	path.exists();
	path.parent();
	path.copy("resources/my-file.txt.bak");


## File (and Directory) APIs

### File and Directory Metadata

* Check if a file exists

		File.exists(path);

* Return the local name of a file (including extension)

		File.fileName(path);

* Return the last time a file or directory was modified

		File.lastModified(path);

* Return the size of a file or directory

		File.size(path);

* Return the path to the parent directory

		File.parent(path);

### File and Directory path types

* Check if a path is a directory

		File.isDirectory(path);

* Check if a path is relative (starts with ./ or ../)

		File.isRelativePath(path);

* Check if path is absolute (unix or windows style pathing)

		File.isAbsolutePath(path);

### Comparison between paths

* Check if one path is more recent than another

		File.outdates(source, target);

* Check if two paths are equal (resolving both as absolute paths)

		File.equals(path1, path2);

### File and directory path conversion

* Convert a path to appropriate slashes for relative or absolute path on each os

		File.nativePath(path);

* Convert a path to an absolute one based on current working directory

		File.absolutePath(path);

* Convert a source path relative to another target path

		File.relativePath(source, target);

* Append a path to an existing directory (or parent of a file)

		File.append(path, subPath);	

	
### File and directory manipulation

* Remove a file or empty directory

		File.remove(path);

* Copy a file or directory

		File.copy(fromPath, toPath);

* Move a file or directory to a new path

		File.move(fromPath, toPath);

### String files

* Read the stirng contents of a file

		File.read(path);

* Overwrite or append string contents of a file
  
		File.write(path, content, overwrite|append)


## Directory specific APIs

* Check if a directory is empty

		Directory.isEmpty(path);

* Recursively remove a directory and its contents

		Directory.removeTree(path);

* Create an empty directory

		Directory.create(path);

* Return a list of the contents of a directory

		Directory.readDirectory(path);

* Get a filtered list of paths using glob
	
		for (path in Directory.glob("*/foo/**.hx"))
		{
			File.remove(path);
		}

* Double filter a list of paths using glob and regexp
	
		using Directory;

		...

		var reg = ~/[^.].*/;

		for(path in "*/foo/**".glob().filter(reg))
		{
			path.remove();
		}

* Zip the contents of a directory

		Directory.zip(fromPath, toPath, includeDirectory);


