package mtask.core;

import msys.File;
import msys.System;
import msys.Path;
import Type;

/**
	The setup module provides a task for stepping through basic mtask 
	configuration including creating a bash shortcut, configuring sublime, 
	and opening user.json and the global build config.
**/
class Setup extends mtask.core.Module
{
	public function new()
	{
		super();
		moduleName = "core";
	}

	/**
		Removes all builds from ${mtask.home}bin
	**/
	@task function reset()
	{
		rm("${mtask.home}bin");
	}

	/**
		Gets or sets an mtask configuration key
	**/
	@task function config(?key:String, ?value:String, ?global:Bool=false)
	{
		if (value == null)
		{
			var value = key == null ? untyped build.env.data : build.env.get(key);
			if (Type.typeof(value) == TObject) trace(Settings.PrettyJson.stringify(value));
			else trace(value);
		}
		else
		{
			if (key == null)
				throw new mtask.core.Error("Cannot configure null key");

			var settings = new Settings();
			var path = "project.json";

			if (global)
			{
				path = msys.Path.join([msys.System.userDirectory, ".mtask/config.json"]);
			}
			else
			{
				if (!build.isProject) throw "Cannot set local config outside of project!";
			}

			var settings = new Settings();
			settings.load(path);
			settings.set(key, value);
			settings.save(path);
		}
	}
	/**
		Runs mtask configuration
	**/
	@task function setup()
	{
		// create command line shortcut
		if (System.isWindows) createBatchShortcut();
		else createBashAlias();

		// install sublime module
		var packages = Path.join([msys.System.dataDirectory, "Sublime Text 2", "Packages"]);

		if (exists(packages) && File.isDirectory(packages))
		{
			var path = Path.join([packages, "MassiveTask"]);

			if (!exists(path) && question("Install the mtask sublime package"))
			{
				var module = Path.normalize(replaceArgs("${lib.mtask}module/sublime/package"));
				cp(module, path);
			}
		}
	}

	function createBatchShortcut()
	{
		var home = Sys.getEnv("HAXEPATH");

		if (home == null)
		{
			Console.warn("Setup could create a shortcut for you, but HAXEPATH is not set.");
			return;
		}

		var batch = msys.Path.join([home, "mtask.bat"]);

		if (!exists(batch) && question("Create shortcut for 'haxelib run mtask' in '" + batch + "'"))
		{
			write(batch, "@haxelib run mtask %*");
		}
	}

	function createBashAlias()
	{
		var profiles = [];
		profiles.push(Path.join([msys.System.userDirectory, ".bashrc"]));
		profiles.push(Path.join([msys.System.userDirectory, ".profile"]));
		profiles.push(Path.join([msys.System.userDirectory, ".bash_profile"]));

		var profile = null;

		for (path in profiles)
		{
			if (exists(profile))
			{
				profile = path;
				break;
			}
		}

		if (profile == null) profile = profiles[0];
		var alias = "alias mtask='haxelib run mtask' # mtask alias\n";

		if (exists(profile))
		{
			var content = read(profile);

			if (content.indexOf(alias) == -1)
			{
				if (question("Would you like to create an alias for 'haxelib run mtask' in '" + profile + "'"))
				{
					if (content.charAt(content.length - 1) != "\n") content += "\n";
					write(profile, content + "\n" +  alias);
					Console.info("Run 'source " + profile + "' to use alias");
				}
			}
		}
		else
		{
			if (question("Would you like to create an alias for 'haxelib run mtask' in '" + profile + "'"))
			{
				write(profile, alias);
				Console.info("Run 'source " + profile + "' to use alias");
			}
		}
	}

	function question(message:String):Bool
	{
		Console.warn(message + "? [y/n]");
		return Sys.stdin().readLine() == "y";
	}

	/**
		Upgrade project.json for mtask 1.4

		Checks if project.json uses pre 1.3.4 project.json syntax, with project 
		settings on the root object. If so, upgrades by moving the data to 
		a child object named "project"
		
			{ "id":"myproject" }
		=>
			{ "project": { "id":"myproject" }}
	**/
	@task("upgrade:project") function upgradeProject()
	{
		if (!build.isProject) return;
		if (!question("Warning: project will no longer be compatable with mtask < 1.4")) return;

		var settings = new Settings();
		settings.load("project.json");
		if (settings.get("project") == null)
		{
			Console.warn("Upgrading project.json");
			untyped settings.data = {project:settings.data};
			settings.save("project.json");
		}
	}
}
