package msys;

class System
{
	/**
	Is the application currently running on a Win32 system.
	*/
	public static var isWindows(default, null):Bool = Sys.systemName() == "Windows";

	/**
	Is the application currently running on a Win32 system.
	*/
	public static var isMac(default, null):Bool = Sys.systemName() == "Mac";

	/**
	Is the application currently running on a Linux system.
	*/
	public static var isLinux(default, null):Bool = Sys.systemName() == "Linux";

	/**
	Is the application currently running on a unix like system (Mac or Linux)
	*/
	public static var isUnix(default, null):Bool = isMac || isLinux;

	/**
	Is the application running under cygwin.
	*/
	public static var isCygwin(default, null):Bool = isWindows && Sys.getEnv("QMAKESPEC") != null && Sys.getEnv("QMAKESPEC").indexOf("cygwin") > -1;

	/**
	The users home directory: ~/ on posix systems, \Users\username on Win32 systems.
	*/
	public static var userDirectory(default, null):String = isWindows ? Sys.getEnv("USERPROFILE") : Sys.getEnv("HOME");

	/**
	The system temp directory.
	*/
	public static var tempDirectory(default, null):String =
	{
		if (isWindows) Sys.getEnv("TEMP");
		else if (isUnix) Sys.getEnv("TMPDIR");
		else "/tmp";
	}

	/**
	The system application data directory.
	*/
	public static var dataDirectory(default, null):String =
	{
		if (isWindows) Sys.getEnv("APPDATA");
		else if (isMac) userDirectory + "/Library/Application Support";
		else userDirectory;
	}
}
