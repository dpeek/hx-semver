## Targets

MTask's main reason for being is the unique challenge of managing multi target 
applications in a way that maximises code and asset reuse and minimizes 
configuration and toolchain management. The build system strives to be simple, 
consistent and yet completely configurable in situations where developers 
require custom behviour.

A target is the compiled output of the `build` task consisting of static assets 
and compiled programs. Assets might consist of images and data used by the 
application at runtime, as well as package metadata and icons. Programs are 
compiled using Haxe or other toolchains, with mtask providing configuration and 
additonal input.

To manage the complex matrix of possible platform, runtime, device, library and 
technology combinations targets define a set of `flags` used to determine it's 
makeup. These flags are a simple array of string identifiers used to determine 
configuration, assets and source paths used when compiling the target.

Some examples of target flags:

	iPhone: nme, mobile, ios, touch, iphone
	Xoom: nme, tablet, android, touch, xoom
	Samsung TV: js, tv, key, 720p, samsung

A simple set of rules define how the build process configures each target, 
allowing developers to compose functionality and assets into a single optimized 
package, while affording them complete control over customization.


### Build Process

The target build process consists of three phases:

1. **Configuration**: the target uses it's properties and additional config from 
   the invoking task to prepare for compilation. This could involve checking 
   for dependencies, generating templates values or invoking other tasks.
2. **Compilation**: the target searches the project and active plugins for files 
   that it will be created from. These are resolved according to the file 
   resolution rules defined below. This set of target files are then processed 
   into the target path.
3. **Bundling**: the target executes any post processing required to produce the 
   final package. This could be as simple as creating an archive, or involve 
   interaction with third party tools.

Each concrete target can override the `configure`, `compile` and `bundle` 
methods with target specific build behavior. Targets can also define methods 
for processing particular types of files during compilation.


#### File Resolution

Targets consist of files resolved by searching the project and active plugins 
based on the targets flags. The lookup rules are:

1. Check each active plugin for a `module` directory, and the project for a 
   `target` directory. These paths are called 'module sources'.
2. Search each module source for modules matching the devices flags. These 
   paths are called the target's 'modules'. Modules are prioritised by their 
   index in this array – project modules take priority over plugin modules, and 
   modules with higher flag priority trump those with lower flag priority.
3. A recursive glob collects files from each target module's `target` 
   directory. If file's local path (path relative to the module's `target` 
   directory) exists in the target, the file is ignored.
4. If a directory defines a flag suffix like `dir@flag` that does not exist in 
   the target flags, the files it contains will be ignored.
5. If a file defines a flag suffix like `file@flag.txt` it is used to determine 
   priority within the module (where other files with the same base name 
   exist). Files with the same base name in modules with higher priority 
   will always take priority.

For a target with the flags:

	["web", "mobile", "html5-video"]

And the plugins/modules/project:

	/plugin1/module
		web/target/
			index.html
			styles.css
			player.js
		android/target/
		mobile/target/
			index.html
	/plugin2/module
		web/target/
			img@mobile/
				graphic.png
			img@tv/
				graphic.png
			styles.css
		html5-video/target/
			player.js
	./target
		web/target/
			img/
				icon.jpg
				icon@html5-video.jpg
				background.jpg
		mobile/target/
			img/
				background.jpg

The resolved files would be:

	target/
		index.html           <- /plugin1/module/mobile/target/index.html (mobile flag higher)
		styles.css           <- /plugin2/module/web/target/styles.css (plugin2 priority)
		player.js            <- /plugin2/html5-video/target/player.js
		img/
			background.jpg   <- ./target/mobile/target/img/background.jpg
			graphic.png      <- /plugin2/module/web/target/img@mobile/graphic.png
			icon.jpg         <- ./target/web/target/img/icon@html5-video.jpg.jpg

The result of the file resolution process is an array of `TargetFile` objects 
defining the absolute (source) path and local (within the target) paths.
	
	[
		{ local:'index.html', absolute:'/plugin1/module/mobile/target/index.html' },
		{ local:'img/background.jpg', absolute:'./target/mobile/target/img/background.jpg' }
		// ...
	]


#### File Processing

Once the files making up the target have been resolved, they are processed. 
Each TargetFile is matched against a set of registered patterns, collected, and 
then passed to a registered processor. The target base class defines handlers 
for files ending in '.hxml' and '.temp':

	addMatcher("\\.hxml$", processHxmls);
	addMatcher("\\.temp$", processTemplates);

Once TargetFiles have been collected, each processor is invoked with the 
collected files:

	function processHxmls(files:Array<TargetFile>)
	{
		// process hxmls
	}

If a file does not match any registered matchers, it is passed to the 
`processUnmatched` method, which has the default behavior of copying the file 
into the target.


#### HXML Processing

During target compilation, files ending in `.hxml` are collected and passed to 
the `processHxmls` method. In the base `Target` implementation, file matching 
the pattern `file.ext.hxml` are compiled using the Haxe compiler. Arguments 
are parsed from the hxml file, with references to other hxml files being 
resolved from the TargetFiles relative to the target.

It is not necessary to define the output path in your hxml, as this is inferred 
from the file name.

	-main Main
	-src src
	common.hxml

Where common arguments would be parsed from the TargetFile

	{ local:"common.hxml", absolute:"some/plugin/common.hxml" }


#### Template Processing

Files ending in `.temp` are processed as templates. During compilation the build 
system loads the content of the source file, replaces any tokens with the 
target as the context, and writes the output (without the `.temp` extension).
