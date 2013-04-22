## Configuration

Mtask offers a simple mechnism for providing configuration to your builds, 
targets and projects. The `build.env` object allows tasks and targets to 
retrieve configuration values using dot notation:

	env.get("user.name");

At startup, env loads a number of JSON configuration files into the same 
object, allowing for cascading values defined globally, for a project, or for 
a specific user. The order in which configurations are loaded:
	
	lib/mtask/config.json  # defaults
	~/.mtask/config.json   # global

	# if in project
	./project.json         # project
	./user.json            # user

Objects defined in each configuration file are merged, so that `user.json` can 
override values defined in `project.json`, for example.
	
	# config.json

	{
		"user":
		{
			"name": "foo"
		}
		"bar": "baz"
	}

	# project.json

	{
		"user":
		{
			"gender": "male"
		}
		"bar": "booze"
	}

	# result

	{
		"user":
		{
			"name": "foo",
			"gender": "male"
		}
		"bar": "booze"
	}

Configuration values can be checked and modified using the `config` task:

	# set the global value of user.name
	mtask config user.name david.peek -global

	# set a project value for user.name
	mtask config user.name build.user

	# print all the values defined in user
	mtask config user

	# print all config for current context
	mtask config
