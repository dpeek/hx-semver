package mtask.core;

/**
	The help module defines the `help` task, which either lists available 
	tasks and the first line of their docs, or the full docs for a specific 
	task.
**/
class Help extends Module
{
	public function new()
	{
		super();
		moduleName = "core";
	}

	/**
		List all tasks, or docs for `task`
	**/
	@task function help(?task:String)
	{
		if (task == null)
		{
			var groups:Array<{name:String, tasks:Array<Task>}> = [];

			for (module in build.modules)
			{
				var group = null;

				for (g in groups)
				{
					if (g.name == module.moduleName)
					{
						group = g;
					}
				}

				if (group == null)
				{
					group = {name:module.moduleName, tasks:[]};
					groups.push(group);
				}

				group.tasks = group.tasks.concat(module.tasks);
			}

			for (group in groups)
			{
				if (group.tasks.length > 0)
				{
					Console.group(group.name);
					printTasks(group.tasks);
					Console.groupEnd();
				}
			}
		}
		else
		{
			printTask(build.getTask(task));
		}
	}

	/**
		Prints an array of tasks to stdout.
	**/
	function printTasks(tasks:Array<Task>)
	{
		var l = 15;
		
		for (task in tasks)
		{
			if (task.id.length > l)
			{
				l = task.id.length;
			}
		}
		
		for (task in tasks)
		{
			var line = mconsole.Style.blue(StringTools.rpad(task.id, " ", l)) + " " + mconsole.Style.white(replaceArgs(task.help));
			Console.log(line);
		}
	}

	/**
		Prints documentation for a task, including automatically generated 
		usage based on task options.
	**/
	function printTask(task:Task)
	{
		var lines = replaceArgs(task.docs).split("\n");
		Console.log(lines.shift());

		var usage = task.id;
		var rest = false;
		for (option in task.options)
		{
			if (option.name == "rest" && option.type == "Dynamic")
			{
				rest = true;
				continue;
			}
			var o = "-" + option.name + " <" + option.type.split(".").pop().toLowerCase() + ">";
			if (option.optional) o = "[" + o + "]";
			usage += " " + o;
		}

		if (rest) usage += " [...]";
		Console.log("\n  " +  mconsole.Style.blue("mtask " + usage) + "\n");

		if (lines.length > 0) Console.log(StringTools.trim(lines.join("\n")));
	}
}
