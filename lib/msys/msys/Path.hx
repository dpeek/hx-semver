package msys;

using Lambda;

class Path
{
	public static var sep = System.isWindows ? "\\" : "/";
	public static var delimiter = ";";

	inline static function isEmptyString(value:String):Bool
	{
		return value == null || value == "";
	}

	#if macro
	static var splitPathRe = null;
	static var splitDeviceRe = msys.System.isWindows ? ~/^([a-zA-Z]:|[\\\/]{2}[^\\\/]+[\\\/][^\\\/]+)?([\\\/])?([\s\S]*?)$/ : null;
	static var splitTailRe = null;
	#else
	/**
	Split a filename into [root, dir, basename, ext], unix version. 'root' is 
	just a slash, or nothing.
	*/
	static var splitPathRe = ~/^(\/?)([\s\S]+\/(?!$)|\/)?((?:\.{1,2}$|[\s\S]+?)?(\.[^.\/]*)?)$/;

	/**
	EReg to split a windows path into three parts: [*, device, slash, tail] (windows-only)
	*/
	static var splitDeviceRe = ~/^([a-zA-Z]:|[\\\/]{2}[^\\\/]+[\\\/][^\\\/]+)?([\\\/])?([\s\S]*?)$/;

	/**
	EReg to split the tail part of the above into [*, dir, basename, ext] (windows-only)
	*/
	static var splitTailRe = ~/^([\s\S]+[\\\/](?!$)|[\\\/])?((?:\.{1,2}$|[\s\S]+?)?(\.[^.\/\\]*)?)$/;
	#end

	inline static function or<T>(value:T, orValue:T):T
	{
		return value == null ? orValue : value;
	}

	public static function split(path:String):Array<String>
	{
		return normalizeArray(path.split(sep));
	}

	/**
	Resolves . and .. elements in a path array with directory names there
	must be no slashes, empty elements, or device names (c:\) in the array
	(so also no leading and trailing slashes - it does not distinguish
	relative and absolute paths)
	*/
	public static function normalizeArray(parts:Array<String>, ?allowAboveRoot:Bool=false):Array<String>
	{
		// if the path tries to go above the root, `up` ends up > 0
		var up = 0;
		var index = parts.length - 1;

		for (i in 0...parts.length)
		{
			var j = index - i;
			var last = parts[j];

			if (last == ".")
			{
				parts.splice(j, 1);
			}
			else if (last == "..")
			{
				parts.splice(j, 1);
				up++;
			}
			else if (up != 0)
			{
				parts.splice(j, 1);
				up--;
			}
		}

		// if the path is allowed to go above the root, restore leading ..s
		if (allowAboveRoot)
		{
			while (up-- > 0) parts.unshift('..');
		}
		
		return parts;
	}

	/**
	Function to split a filename into [root, dir, basename, ext]
	*/
	public static function splitPath(path:String):Array<String>
	{
		if (System.isWindows)
		{
			if (splitDeviceRe.match(path))
			{
				var device = or(splitDeviceRe.matched(1), "") + or(splitDeviceRe.matched(2), "");
				var tail = or(splitDeviceRe.matched(3), "");

				// Split the tail into dir, basename and extension
				if (splitTailRe.match(tail))
				{
					return [device,
						or(splitTailRe.matched(1), ""),
						or(splitTailRe.matched(2), ""),
						or(splitTailRe.matched(3), "")];
				}
			}
		}
		else
		{
			if (splitPathRe.match(path))
			{
				return [or(splitPathRe.matched(1), ""),
					or(splitPathRe.matched(2), ""),
					or(splitPathRe.matched(3), ""),
					or(splitPathRe.matched(4), "")];
			}
		}
		
		return ["", "", "", ""];
	}
	
	/**
	Return the directory name of a path. Similar to the Unix dirname command.
	*/
	public static function dirname(path:String)
	{
		var result = splitPath(path);
		var root = result[0];
		var dir = result[1];

		// No dirname whatsoever
		if (root == "" && dir == "") return ".";

		// It has a dirname, strip trailing slash
		if (dir != "") dir = dir.substr(0, dir.length - 1);
		
		return root + dir;
	}

	/**
	Return the last portion of a path. Similar to the Unix basename command.
	*/
	public static function basename(path:String, ?ext:String):String
	{
		var f = splitPath(path)[2];
		// TODO: make this comparison case-insensitive on windows?
		if (!isEmptyString(ext) && f.substr(-1 * ext.length) == ext)
		{
			f = f.substr(0, f.length - ext.length);
		}
		return f;
	}

	public static function extname(path:String):String
	{
		return splitPath(path)[3];
	}

	public static function normalize(path:String)
	{
		return if (System.isWindows) normalizeWindows(path);
		else normalizeUnix(path);
	}

	public static function join(paths:Array<String>):String
	{
		return if (System.isWindows) joinWindows(paths);
		else joinUnix(paths);
	}


	public static function resolve(paths:Array<String>)
	{
		paths = paths.copy();
		return if (System.isWindows) resolveWindows(paths);
		else resolveUnix(paths);
	}

	public static function relative(from:String, to:String)
	{
		return if (System.isWindows) relativeWindows(from, to);
		else relativeUnix(from, to);
	}

	//--------------------------------------------------------------------------------------------- unix

	static function joinUnix(paths:Array<String>)
	{
		return normalize(paths.filter(function(p) {
			return Std.is(p, String) && !isEmptyString(p);
		}).array().join(sep));
	}

	static function resolveUnix(paths:Array<String>)
	{
		var resolvedPath = "";
		var resolvedAbsolute = false;

		for (i in 0...paths.length + 1)
		{
			var path = paths.length > 0 ? paths.pop() : Sys.getCwd();
			if (!Std.is(path, String)) continue;

			resolvedPath = path + sep + resolvedPath;
			resolvedAbsolute = path.charAt(0) == sep;

			if (resolvedAbsolute) break;
		}

		// At this point the path should be resolved to a full absolute path, but
		// handle relative paths to be safe (might happen when process.cwd() fails)

		// Normalize the path
		resolvedPath = normalizeArray(resolvedPath.split(sep).filter(function(p) {
			return !isEmptyString(p);
		}).array(), !resolvedAbsolute).join(sep);

		var resolved = ((resolvedAbsolute ? '/' : '') + resolvedPath);
		return resolved.length > 0 ? resolved : '.';
	}

	static function normalizeUnix(path:String)
	{
		var isAbsolute = path.charAt(0) == sep;
		var trailingSlash = path.charAt(path.length - 1) == sep;
		
		// Normalize the path
		path = normalizeArray(path.split(sep).filter(function(p) {
			return !isEmptyString(p);
		}).array(), !isAbsolute).join(sep);

		if (isEmptyString(path) && !isAbsolute) path = '.';
		if (!isEmptyString(path) && trailingSlash) path += sep;

		return (isAbsolute ? sep : "") + path;
	}

	public static function relativeUnix(from:String, to:String)
	{
		from = resolve([from]).substr(1);
		to = resolve([to]).substr(1);

		function trim(arr:Array<String>)
		{
			var start = 0;

			while (start < arr.length)
			{
				if (arr[start] != "") break;
				start += 1;
			}

			var end = arr.length - 1;

			while (end >= 0)
			{
				if (arr[end] != "") break;
				end -= 1;
			}

			if (start > end) return [];
			return arr.slice(start, end - start + 1);
		}

		var fromParts = trim(from.split(sep));
		var toParts = trim(to.split(sep));

		var length = Std.int(Math.min(fromParts.length, toParts.length));
		var samePartsLength = length;

		for (i in 0...length)
		{
			if (fromParts[i] != toParts[i])
			{
				samePartsLength = i;
				break;
			}
		}

		var outputParts = [];
		for (i in samePartsLength...fromParts.length) outputParts.push("..");

		outputParts = outputParts.concat(toParts.slice(samePartsLength));
		return outputParts.join(sep);
	}

	//--------------------------------------------------------------------------------------------- windows

	static function joinWindows(paths:Array<String>):String
	{
		paths = paths.filter(function(p){
			return Std.is(p, String) && !isEmptyString(p);
		}).array();
		var joined = paths.join('\\');

		// Make sure that the joined path doesn't start with two slashes
		// - it will be mistaken for an unc path by normalize() -
		// unless the paths[0] also starts with two slashes
		if (~/^[\\\/]{2}/.match(joined) && !~/^[\\\/]{2}/.match(paths[0]))
			joined = joined.substr(1);

		return normalize(joined);
	}

	public static function resolveWindows(paths:Array<String>)
	{
		var resolvedDevice = "";
		var resolvedTail = "";
		var resolvedAbsolute = false;

		for (i in 0...paths.length + 1)
		{
			var path:String;

			if (i < paths.length)
			{
				path = paths[paths.length - (i + 1)];
			}
			else if (isEmptyString(resolvedDevice))
			{
				path = FS.pwd();
			}
			else
			{
				// Windows has the concept of drive-specific current working
				// directories. If we've resolved a drive letter but not yet an
				// absolute path, get cwd for that drive. We're sure the device is not
				// an unc path at this points, because unc paths are always absolute.
				path = Sys.getEnv("=" + resolvedDevice);
				
				// Verify that a drive-local cwd was found and that it actually points
				// to our drive. If not, default to the drive's root.
				if (isEmptyString(path) || path.substr(0, 3).toLowerCase() != resolvedDevice.toLowerCase() + '\\')
					path = resolvedDevice + '\\';
			}
			
			// Skip empty and invalid entries
			if (isEmptyString(path) || !Std.is(path, String)) continue;
			splitDeviceRe.match(path);

			var device = or(splitDeviceRe.matched(1), "");
			var isUnc = !isEmptyString(device) && device.charAt(1) != ':';
			var isAbsolute = !isEmptyString(splitDeviceRe.matched(2)) || isUnc; // UNC paths are always absolute
			var tail = splitDeviceRe.matched(3);
			
			if (!isEmptyString(device)
			&& !isEmptyString(resolvedDevice)
			&& device.toLowerCase() != resolvedDevice.toLowerCase())
			{
				// This path points to another device so it is not applicable
				continue;
			}

			if (isEmptyString(resolvedDevice))
			{
				resolvedDevice = device;
			}

			if (!resolvedAbsolute)
			{
				resolvedTail = tail + '\\' + resolvedTail;
				resolvedAbsolute = isAbsolute;
			}

			if (!isEmptyString(resolvedDevice) && resolvedAbsolute) break;
		}

		// Replace slashes (in UNC share name) by backslashes
		resolvedDevice = new EReg("\\/", "g").replace(resolvedDevice, "\\");

		// At this point the path should be resolved to a full absolute path,
		// but handle relative paths to be safe (might happen when process.cwd()
		// fails)
		
		// Normalize the tail path
		resolvedTail = normalizeArray(new EReg("[\\\\/]+", "g").split(resolvedTail).filter(function(p) {
		  return !isEmptyString(p);
		}).array(), !resolvedAbsolute).join("\\");
		
		var result = resolvedDevice + (resolvedAbsolute ? "\\" : "") + resolvedTail;
		return result == "" ? "." : result;
	}

	static function normalizeWindows(path:String)
	{
		splitDeviceRe.match(path);

		var device = or(splitDeviceRe.matched(1), "");
		var isUnc = !isEmptyString(device) && device.charAt(1) != ':';
		var isAbsolute = !isEmptyString(splitDeviceRe.matched(2)) || isUnc; // UNC paths are always absolute
		var tail = splitDeviceRe.matched(3);
		var trailingSlash = new EReg("[\\\\/]$", "").match(tail);

		// Normalize the tail path
		tail = normalizeArray(new EReg("[\\\\/]+", "g").split(tail).filter(function(p) {
		  return !isEmptyString(p);
		}).array(), !isAbsolute).join("\\");

		if (isEmptyString(tail) && !isAbsolute) tail = ".";
		if (!isEmptyString(tail) && trailingSlash) tail += "\\";

		// Convert slashes to backslashes when `device` points to an UNC root.
		device = new EReg("/", "g").replace(device, "\\");

		return device + (isAbsolute ? '\\' : '') + tail;
	}

	/**
	it will solve the relative path from 'from' to 'to', for instance:
	from = 'C:\\orandea\\test\\aaa'
	to = 'C:\\orandea\\impl\\bbb'
	The output of the function should be: '..\\..\\impl\\bbb'
	*/
	public static function relativeWindows(from:String, to:String)
	{
		from = resolve([from]);
		to = resolve([to]);

		// windows is not case sensitive
		var lowerFrom = from.toLowerCase();
		var lowerTo = to.toLowerCase();

		function trim(arr:Array<String>)
		{
			var start = 0;

			while (start < arr.length)
			{
				if (arr[start] != "") break;
				start += 1;
			}

			var end = arr.length - 1;

			while (end >= 0)
			{
				if (arr[end] != "") break;
				end -= 1;
			}

			if (start > end) return [];
			return arr.slice(start, end - start + 1);
		}

		var toParts = trim(to.split("\\"));

		var lowerFromParts = trim(lowerFrom.split("\\"));
		var lowerToParts = trim(lowerTo.split("\\"));

		var length = Std.int(Math.min(lowerFromParts.length, lowerToParts.length));
		var samePartsLength = length;
		for (i in 0...length)
		{
			if (lowerFromParts[i] != lowerToParts[i])
			{
				samePartsLength = i;
				break;
			}
		}

		if (samePartsLength == 0)
		{
		  return to;
		}

		var outputParts = [];
		for (i in samePartsLength...lowerFromParts.length)
		{
			outputParts.push("..");
		}

		outputParts = outputParts.concat(toParts.slice(samePartsLength));
		return outputParts.join("\\");
	}
}

/*
if (isWindows) {
  exports._makeLong = function(path) {
	path = '' + path;
	if (!path) {
	  return '';
	}

	var resolvedPath = exports.resolve(path);

	if (/^[a-zA-Z]\:\\/.test(resolvedPath)) {
	  // path is local filesystem path, which needs to be converted
	  // to long UNC path.
	  return '\\\\?\\' + resolvedPath;
	} else if (/^\\\\[^?.]/.test(resolvedPath)) {
	  // path is network UNC path, which needs to be converted
	  // to long UNC path.
	  return '\\\\?\\UNC\\' + resolvedPath.substring(2);
	}

	return path;
  };
} else {
  exports._makeLong = function(path) {
	return path;
  };
}
*/
