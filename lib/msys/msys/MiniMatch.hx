package msys;

using Lambda;

/**
All options are `false` by default.
*/
typedef MiniMatchOptions = {
	/**
	Suppress the behavior of treating `#` at the start of a pattern as a comment.
	*/
	@:optional var nocomment:Bool;

	/**
	Disable `**` matching against multiple folder names.
	*/
	@:optional var noglobstar:Bool;

	/**
	Allow patterns to match filenames starting with a period, even if the 
	pattern does not explicitly have a period in that spot.

	Note that by default, `a/**\/b` will not match `a/.d/b`, unless dot is set.
	*/
	@:optional var dot:Bool;

	/**
	Perform a case-insensitive match.
	*/
	@:optional var nocase:Bool;

	/**
	When a match is not found by `MiniMatch.matchPath`, return a list 
	containing the pattern itself. When set, an empty list is returned if there 
	are no matches.
	*/
	@:optional var nonull:Bool;

	/**
	Suppress the behavior of treating a leading `!` character as negation.
	*/
	@:optional var nonegate:Bool;

	/**
	Do not expand `{a,b}` and `{1..3}` brace sets.
	*/
	@:optional var nobrace:Bool;

	/**
	Disable "extglob" style patterns like `+(a|b)`.
	*/
	@:optional var noext:Bool;

	/**
	Returns from negate expressions the same as if they were not negated. 
	(ie, `true` on a hit, `false` on a miss.)
	*/
	@:optional var flipNegate:Bool;

	/**
	If set, then patterns without slashes will be matched against the basename 
	of the path if it contains slashes. For example, `a?b` would match the path 
	`/xyz/123/acb`, but not `/xyz/acb/123`.
	*/
	@:optional var matchBase:Bool;

	/**
	Print debug information.
	*/
	@:optional var debug:Bool;
}

/**
Possible pattern types in `set`
*/
enum Pattern
{
	/**
	A string constant token
	*/
	string(v:String);

	/**
	A recursive directory matcher.
	*/
	globstar;

	/**
	A regex based matcher.
	*/
	matcher(ereg:EReg, src:String, glob:String);

	/**
	A matcher that was unable to be parsed.
	*/
	error;

	/**
	An empty matcher.
	*/
	nullEreg;

	/**
	An internal matcher type.
	*/
	partial(re:String, magic:Bool);
}

class MiniMatch
{
	public static function joinPattern(pattern:Array<Pattern>):String
	{
		return pattern.map(function(p) {
			return switch (p)
			{
				case Pattern.string(v): v;
				default: "";
			}
		}).join(Path.sep);
	}

	/**
	Tests a path against the pattern using the options.

		var isJS = minimatch(file, "*.js", { matchBase: true })
	*/
	public static function matchPath(path:String, pattern:String, ?options:MiniMatchOptions):Bool
	{
		var mm = new MiniMatch(pattern, options);
		return mm.match(path);
	}

	/**
	Match against the list of files, in the style of fnmatch or glob. If 
	nothing is matched, and options.nonull is set, then return a list 
	containing the pattern itself.

		var javascripts = minimatch.match(fileList, "*.js", {matchBase: true}))
	*/
	public static function matchPaths(paths:Array<String>, pattern:String, ?options:MiniMatchOptions):Array<String>
	{
		var mm = new MiniMatch(pattern, options);
		
		paths = paths.filter(function(f) {
			return mm.match(f);
		}).array();

		if (options.nonull && paths.length == 0)
			paths.push(pattern);

		return paths;
	}

	/**
	Returns a function that tests its supplied argument, suitable for use with 
	`Lambda.filter`.
		
		using Lambda;
		var javascripts = fileList.filter(MiniMatch.filter("*.js", {matchBase:true}))
	*/
	public static function filter(pattern:String, ?options:MiniMatchOptions):String -> Bool
	{
		var mm = new MiniMatch(pattern, options);
		return function(path:String):Bool
		{
			return mm.match(path);
		}
	}

	/**
	Make a regular expression object from the pattern.
	*/
	public static function matcher(pattern:String, ?options:MiniMatchOptions):EReg
	{
		return new MiniMatch(pattern, options).makeRe();
	}

	public static var NULLEREG = ~//;

	// any single thing other than /
	// don't need to escape / when using new RegExp()
	static var qmark = "[^/]";

	// * => any number of characters
	static var star = qmark + "*?";

	// ** when dots are allowed.  Anything goes, except .. and .
	// not (^ or / followed by one or two dots followed by $ or /),
	// followed by anything, any number of times.
	static var twoStarDot = "(?:(?!(?:\\/|^)(?:\\.{1,2})($|\\/)).)*?";

	// not a ^ or / followed by a dot,
	// followed by anything, any number of times.
	static var twoStarNoDot = "(?:(?!(?:\\/|^)\\.).)*?";

	// characters that need to be escaped in RegExp.
	static var reSpecials = charSet("().*{}+?[]^$\\!");

	// "abc" -> { a:true, b:true, c:true }
	static function charSet(string:String):Dynamic
	{
		var set = {};
		for (char in string.split(""))
			Reflect.setField(set, char, true);
		return set;
	}

	/**
	Replace stuff like \* with *
	*/
	static function globUnescape(s)
	{
		return ~/\\(.)/g.replace(s, "$1");
	}

	/**
	*/
	function regExpEscape(s)
	{
		return ~/[-[\]{}()*+?.,\\^$|#\s]/g.replace(s, "\\$0");
	}

	// normalizes slashes.
	static var slashSplit = ~/\/+/g;

	/**
	The glob pattern to being matched.
	*/
	public var pattern:String;

	/**
	Options controlling matching.
	*/
	public var options:MiniMatchOptions;

	public var set:Array<Array<Pattern>>;
	public var regexp:EReg;
	public var negate:Bool;
	public var comment:Bool;
	public var empty:Bool;

	var globSet:Array<String>;
	var globParts:Array<Array<String>>;

	public function new(pattern:String, ?options:MiniMatchOptions)
	{
		if (options == null) options = {};
		
		// init
		this.pattern = StringTools.trim(pattern);
		this.options = options;

		// state
		set = [];
		regexp = null;
		negate = false;
		comment = false;
		empty = false;

		// empty patterns and comments match nothing.
		if (!options.nocomment && pattern.charAt(0) == "#")
		{
			comment = true;
			return;
		}
		if (pattern.length == 0)
		{
			empty = true;
			return;
		}

		// step 1: figure out negation, etc.
		parseNegate();

		// step 2: expand braces
		globSet = braceExpand();
		
		// step 3: now we have a set, so turn each one into a series of path-portion
		// matching patterns.
		// These will be regexps, except in the case of "**", which is
		// set to the GLOBSTAR object for globstar behavior,
		// and will not contain any / characters
		
		globParts = globSet.map(function (s) {
			return slashSplit.split(s);
		}).array();

		// glob --> regexps
		set = globParts.map(function(s) {
			return s.map(function(s) {
				return parse(s);
			}).array();
		}).array();

		// filter out everything that didn't compile properly.
		set = set.filter(function(s:Array<Pattern>) {
			return -1 == s.indexOf(Pattern.error);
		}).array();
	}

	function parseNegate()
	{
		negate = false;

		if (options.nonegate) return;
		var offset = 0;

		for (i in 0...pattern.length)
		{
			if (pattern.charAt(i) == "!")
			{
				negate = !negate;
				offset += 1;
			}
			else break;
		}

		if (offset > 0) pattern = pattern.substr(offset);
	}

	/**
	Brace expansion:
	a{b,c}d -> abd acd
	a{b,}c -> abc ac
	a{0..3}d -> a0d a1d a2d a3d
	a{b,c{d,e}f}g -> abg acdfg acefg
	a{b,c}d{e,f}g -> abdeg acdeg abdeg abdfg
	
	Invalid sets are not expanded.
	a{2..}b -> a{2..}b
	a{b}c -> a{b}c
	*/
	public function braceExpand():Array<String>
	{
		if (options.nobrace || !~/\{.*\}/.match(pattern))
		{
			// shortcut. no need to expand.
			return [pattern];
		}

		var escaping = false;

		// examples and comments refer to this crazy pattern:
		// a{b,c{d,e},{f,g}h}x{y,z}
		// expected:
		// abxy
		// abxz
		// acdxy
		// acdxz
		// acexy
		// acexz
		// afhxy
		// afhxz
		// aghxy
		// aghxz

		// everything before the first \{ is just a prefix.
		// So, we pluck that off, and work with the rest,
		// and then prepend it to everything we find.
		if (pattern.charAt(0) != "{")
		{
			var prefix = null;
			var index = 0;

			for (i in 0...pattern.length)
			{
				var c = pattern.charAt(i);
				if (c == "\\")
				{
					escaping = !escaping;
				}
				else if (c == "{" && !escaping)
				{
					prefix = pattern.substr(0, i);
					break;
				}

				index += 1;
			}

			// actually no sets, all { were escaped.
			if (prefix == null) return [pattern];
			var tail = new MiniMatch(pattern.substr(index), options).braceExpand();

			return tail.map(function (t) {
				return prefix + t;
			}).array();
		}

		// now we have something like:
		// {b,c{d,e},{f,g}h}x{y,z}
		// walk through the set, expanding each part, until
		// the set ends.  then, we'll expand the suffix.
		// If the set only has a single member, then put the {} back

		// first, handle numeric sets, since they're easier
		var numset = ~/^\{(-?[0-9]+)\.\.(-?[0-9]+)\}/;
		if (numset.match(pattern))
		{
			var suf = new MiniMatch(pattern.substr(numset.matched(0).length), options).braceExpand();
			var start = Std.parseInt(numset.matched(1));
			var end = Std.parseInt(numset.matched(2));
			var inc = start > end ? -1 : 1;
			var set = [];

			for (i in start...end + inc)
			{
				// append all the suffixes
				for (ii in 0...suf.length)
				{
					set.push(i + suf[ii]);
				}
			}

			return set;
		}

		// ok, walk through the set
		// We hope, somewhat optimistically, that there
		// will be a } at the end.
		// If the closing brace isn't found, then the pattern is
		// interpreted as braceExpand("\\" + pattern) so that
		// the leading \{ will be interpreted literally.
		var i = 1; // skip the \{
		var depth = 1;
		var set = [];
		var member = "";
		var sawEnd = false;
		var escaping = false;

		function addMember () {
			set.push(member);
			member = "";
		}

		var index = 1;
		for (i in 1...pattern.length)
		{
			var c = pattern.charAt(i);

			if (escaping)
			{
				escaping = false;
				member += "\\" + c;
			}
			else
			{
				switch (c)
				{
					case "\\":
						escaping = true;

					case "{":
						depth ++;
						member += "{";

					case "}":
						depth --;
						// if this closes the actual set, then we're done
						if (depth == 0)
						{
							addMember();
							// pluck off the close-brace
							index ++;
							break;
						}
						else
						{
							member += c;
						}

					case ",":
						if (depth == 1) addMember();
						else member += c;

					default:
						member += c;
				}
			}
			index += 1;
		}
		
		// now we've either finished the set, and the suffix is
		// pattern.substr(i), or we have *not* closed the set,
		// and need to escape the leading brace
		if (depth != 0)
		{
			return new MiniMatch("\\" + pattern, options).braceExpand();
		}

		// // x{y,z} -> ["xy", "xz"]
		var suf = new MiniMatch(pattern.substr(index), options).braceExpand();
		// // ["b", "c{d,e}","{f,g}h"] ->
		// //   [["b"], ["cd", "ce"], ["fh", "gh"]]
		var addBraces = set.length == 1;
		var expanded = set.map(function (p) {
			return new MiniMatch(p, options).braceExpand();
		}).array();

		// // [["b"], ["cd", "ce"], ["fh", "gh"]] ->
		// //   ["b", "cd", "ce", "fh", "gh"]
		set = [];
		for (list in expanded) set = set.concat(list);

		if (addBraces)
		{
			set = set.map(function (s) {
				return "{" + s + "}";
			}).array();
		}

		// // now attach the suffixes.
		var ret = [];
		for (i in 0...set.length)
		{
			for (ii in 0...suf.length)
			{
				ret.push(set[i] + suf[ii]);
			}
		}

		return ret;
	}

	/**
	parse a component of the expanded set.
	At this point, no pattern may contain "/" in it
	so we're going to return a 2d array, where each entry is the full
	pattern, split on '/', and then turned into a regular expression.
	A regexp is made at the end which joins each array with an
	escaped /, and another full one which joins each regexp with |.
	
	Following the lead of Bash 4.1, note that "**" only has special meaning
	when it is the *only* thing in a path portion.  Otherwise, any series
	of * is equivalent to a single *.  Globstar behavior is enabled by
	default, and can be disabled by setting options.noglobstar.
	*/
	function parse(pattern:String, ?isSub:Bool=false):Pattern
	{
		// shortcuts
		if (!options.noglobstar && pattern == "**") return Pattern.globstar;
		if (pattern == "" && !isSub) return Pattern.string("");

		var re = "";
		var hasMagic = false;
		var escaping = false;
		// ? => one single character
		var patternListStack = [];
		var plType:String = null;
		var stateChar:String = null;
		var inClass = false;
		var reClassStart = -1;
		var classStart = -1;

		// . and .. never match anything that doesn't start with .,
		// even when options.dot is set.
		var patternStart = pattern.charAt(0) == "." ? "" // anything
			// not (start or / followed by . or .. followed by / or end)
			: options.dot ? "(?!(?:^|\\/)\\.{1,2}(?:$|\\/))"
			: "(?!\\.)";

		function clearStateChar()
		{
			if (stateChar != null)
			{
				// we had some state-tracking character
				// that wasn't consumed by this pass.
				switch (stateChar)
				{
					case "*":
						re += star;
						hasMagic = true;

					case "?":
						re += qmark;
						hasMagic = true;

					default:
						re += "\\"+stateChar;
				}

				stateChar = null;
			}
		}
		
		for (i in 0...pattern.length)
		{
			var c = pattern.charAt(i);
			
			// skip over any that are escaped.
			if (escaping && Reflect.hasField(reSpecials, c))
			{
				re += "\\" + c;
				escaping = false;
				continue;
			}

			switch (c)
			{
				case "/":
					// completely not allowed, even escaped.
					// Should already be path-split by now.
					return Pattern.nullEreg;

				case "\\":
					clearStateChar();
					escaping = true;
					continue;

				// the various stateChar values
				// for the "extglob" stuff.
				case "?", "*", "+", "@", "!":
					// all of those are literals inside a class, except that
					// the glob [!a] means [^a] in regexp
					if (inClass)
					{
						if (c == "!" && i == classStart + 1) c = "^";
						re += c;
						continue;
					}

					// if we already have a stateChar, then it means
					// that there was something like ** or +? in there.
					// Handle the stateChar, then proceed with this one.
					clearStateChar();
					stateChar = c;
					// if extglob is disabled, then +(asdf|foo) isn't a thing.
					// just clear the statechar *now*, rather than even diving into
					// the patternList stuff.
					if (options.noext) clearStateChar();
					continue;

				case "(":
					if (inClass)
					{
						re += "(";
						continue;
					}

					if (stateChar == null)
					{
						re += "\\(";
						continue;
					}

					plType = stateChar;
					patternListStack.push({type:plType, start:i - 1, reStart:re.length});
					// negation is (?:(?!js)[^/]*)
					re += stateChar == "!" ? "(?:(?!" : "(?:";
					stateChar = null;
					continue;

				case ")":
					if (inClass || patternListStack.length == 0)
					{
						re += "\\)";
						continue;
					}

					hasMagic = true;
					re += ")";
					plType = patternListStack.pop().type;
					// negation is (?:(?!js)[^/]*)
					// The others are (?:<pattern>)<type>
					switch (plType)
					{
						case "!":
							re += "[^/]*?)";
							break;
						case "?", "+", "*":
							re += plType;
						case "@":
							break; // the default anyway
					}
					continue;

				case "|":
					if (inClass || patternListStack.length == 0 || escaping)
					{
						re += "\\|";
						escaping = false;
						continue;
					}

					re += "|";
					continue;

				// these are mostly the same in regexp and glob
				case "[":
					// swallow any state-tracking char before the [
					clearStateChar();

					if (inClass)
					{
						re += "\\" + c;
						continue;
					}

					inClass = true;
					classStart = i;
					reClassStart = re.length;
					re += c;
					continue;

				case "]":
					//  a right bracket shall lose its special
					//  meaning and represent itself in
					//  a bracket expression if it occurs
					//  first in the list.  -- POSIX.2 2.8.3.2
					if (i == classStart + 1 || !inClass)
					{
						re += "\\" + c;
						escaping = false;
						continue;
					}

					// finish up the class.
					hasMagic = true;
					inClass = false;
					re += c;
					continue;

				default:
					// swallow any state char that wasn't consumed
					clearStateChar();

					if (escaping)
					{
						// no need
						escaping = false;
					}
					else if (Reflect.hasField(reSpecials, c) && !(c == "^" && inClass))
					{
						re += "\\";
					}

					re += c;
			}
		}
		
		// handle the case where we left a class open.
		// "[abc" is valid, equivalent to "\[abc"
		if (inClass)
		{
			// split where the last [ was, and escape it
			// this is a huge pita.  We now have to re-walk
			// the contents of the would-be class to re-translate
			// any characters that were passed through as-is
			var cs = pattern.substr(classStart + 1);
			var sp = parse(cs, true);

			switch (sp)
			{
				case Pattern.partial(glob, magic):
					re = re.substr(0, reClassStart) + "\\[" + glob;
					hasMagic = hasMagic || magic;
				default: throw "wtf";
			}
		}
		
		// handle the case where we had a +( thing at the *end*
		// of the pattern.
		// each pattern list stack adds 3 chars, and we need to go through
		// and escape any | chars that were passed through as-is for the regexp.
		// Go through and escape them, taking care not to double-escape any
		// | chars that were already escaped.
		while (patternListStack.length > 0)
		{
			var pl = patternListStack.pop();
			var tail = re.substr(pl.reStart + 3);
			
			// maybe some even number of \, then maybe 1 \, followed by a |
			#if haxe3
			tail = ~/((?:\\{2})*)(\\?)\|/g.map(tail, function(re){
			#else
			tail = ~/((?:\\{2})*)(\\?)\|/g.customReplace(tail, function(re){
			#end
				var match1 = re.matched(1);
				var match2 = re.matched(2);

				if (match2 == "" || match2 == null)
				{
					// the | isn't already escaped, so escape it.
					match2 = "\\";
				}

				// need to escape all those slashes *again*, without escaping the
				// one that we need for escaping the | character.  As it works out,
				// escaping an even number of slashes can be done by simply repeating
				// it exactly after itself.  That's why this trick works.
				//
				// I am sorry that you have to see this.
				return match1 + match1 + match2 + "|";
			});

			// console.error("tail=%j\n   %s", tail, tail)
			var t = pl.type == "*" ? star
						: pl.type == "?" ? qmark
						: "\\" + pl.type;

			hasMagic = true;
			re = re.substr(0, pl.reStart)
				 + t + "\\("
				 + tail;
		}

		// handle trailing things that only matter at the very end.
		clearStateChar();
		if (escaping)
		{
			// trailing \\
			re += "\\\\";
		}

		// only need to apply the nodot start if the re starts with
		// something that could conceivably capture a dot
		var addPatternStart = false;
		switch (re.charAt(0))
		{
			case ".", "[", "(": addPatternStart = true;
		}

		// if the re is not "" at this point, then we need to make sure
		// it doesn't match against an empty path part.
		// Otherwise a/* will match a/, which it should not.
		if (re != "" && hasMagic) re = "(?=.)" + re;

		if (addPatternStart) re = patternStart + re;

		// parsing just a piece of a larger pattern.
		if (isSub)
		{
			return Pattern.partial(re, hasMagic);
		}
		
		// skip the regexp for non-magical patterns
		// unescape anything in it, though, so that it'll be
		// an exact match against a file etc.
		if (!hasMagic)
		{
			return Pattern.string(globUnescape(pattern));
		}

		var flags = options.nocase ? "i" : "";
		return Pattern.matcher(new EReg("^" + re + "$", flags), re, pattern);
	}

	public function makeRe():EReg
	{
		if (regexp != null || regexp == NULLEREG) return regexp;

		// at this point, this.set is a 2d array of partial
		// pattern strings, or "**".
		//
		// It's better to use .match().  This function shouldn't
		// be used, really, but it's pretty convenient sometimes,
		// when you just want to work with a regex.

		if (set.length == 0) return regexp = NULLEREG;

		var twoStar = options.noglobstar ? star
				: options.dot ? twoStarDot
				: twoStarNoDot;
		var flags = options.nocase ? "i" : "";

		var re = set.map(function(pattern) {
			return pattern.map(function(p) {
				return switch (p)
				{
					case Pattern.globstar:twoStar;
					case Pattern.string(v): regExpEscape(v);
					case Pattern.matcher(_, src, _):src;
					default: null;
				}
			}).join("\\/");
		}).join("|");

		// must match entire pattern
		// ending in a * or ** will make it less strict.
		re = "^" + re + "$";

		// can match anything, as long as it's not this.
		if (negate) re = "^(?!" + re + ").*$";

		try
		{
			return regexp = new EReg(re, flags);
		}
		catch (ex:Dynamic)
		{
			return regexp = NULLEREG;
		}
	}

	function match(path:String, ?partial:Bool=false)
	{
		// short-circuit in the case of busted things.
		// comments, etc.
		if (comment) return false;
		if (empty) return path == "";

		if (path == "/" && partial) return true;

		// windows: need to use /, not \
		// On other platforms, \ is a valid (albeit bad) filename char.
		// if (System.isWindows) path = path.split("\\").join("/");
		
		// treat the test path as a set of pathparts.
		var paths = slashSplit.split(path);

		// just ONE of the pattern sets in this.set needs to match
		// in order for it to be valid.  If negating, then just one
		// match means that we have failed.
		// Either way, return on the first hit.
		for (i in 0...set.length)
		{
			var pattern = set[i];
			var hit = matchOne(paths, pattern, partial);

			if (hit)
			{
				if (options.flipNegate) return true;
				return !negate;
			}
		}

		// didn't get any hits. this is success if it's a negative
		// pattern, failure otherwise.
		if (options.flipNegate) return false;
		return negate;
	}

	/**
	set partial to true to test if, for example,
	"/a/b" matches the start of "/*\/b/*\/d" 
	Partial means, if you run out of file before you run
	out of pattern, then that's fine, as long as all
	the parts match.
	*/
	function matchOne(file:Array<String>, pattern:Array<Pattern>, partial:Bool):Bool
	{
		if (options.matchBase && pattern.length == 1)
		{
			file = Path.basename(file.join("/")).split("/");
		}

		var fi = 0;
		var pi = 0;

		var fl = file.length;
		var pl = pattern.length;

		var f:String = null;
		var p:Pattern = null;

		while ((fi < fl) && (pi < pl))
		{
			p = pattern[pi];
			f = file[fi];
			
			// should be impossible.
			// some invalid regexp stuff in the set.
			if (p == Pattern.error) return false;

			if (p == Pattern.globstar)
			{
				// "**"
				// a/** /b/** /c would match the following:
				// a/b/x/y/z/c
				// a/x/y/z/b/c
				// a/b/x/b/x/c
				// a/b/c
				// To do this, take the rest of the pattern after
				// the **, and see if it would match the file remainder.
				// If so, return success.
				// If not, the ** "swallows" a segment, and try again.
				// This is recursively awful.
				// a/b/x/y/z/c
				// - a matches a
				// - doublestar
				//   - matchOne(b/x/y/z/c, b/** /c)
				//     - b matches b
				//     - doublestar
				//       - matchOne(x/y/z/c, c) -> no
				//       - matchOne(y/z/c, c) -> no
				//       - matchOne(z/c, c) -> no
				//       - matchOne(c, c) yes, hit
				var fr = fi;
				var pr = pi + 1;

				if (pr == pl)
				{
					// a ** at the end will just swallow the rest.
					// We have found a match.
					// however, it will not swallow /.x, unless
					// options.dot is set.
					// . and .. are *never* matched by **, for explosively
					// exponential reasons.
					while (fi < fl)
					{
						if (file[fi] == "." || file[fi] == ".." ||
							(!options.dot && file[fi].charAt(0) == ".")) return false;
						fi++;
					}
					return true;
				}

				// ok, let's see if we can swallow whatever we can.
				while (fr < fl)
				{
					var swallowee = file[fr];
					if (swallowee == "." || swallowee == ".." || (!options.dot && swallowee.charAt(0) == ".")) break;

					// XXX remove this slice.  Just pass the start index.
					if (matchOne(file.slice(fr), pattern.slice(pr), partial))
					{
						// found a match.
						return true;
					}
					else
					{
						// ** swallows a segment, and continue.
						fr += 1;
					}
				}

				// no match was found.
				// However, in partial mode, we can't say this is necessarily over.
				// If there's more *pattern* left, then 
				if (partial)
				{
					// ran out of file
					if (fr == fl) return true;
				}

				return false;
			}

			// something other than **
			// non-magic patterns just have to match exactly
			// patterns with magic have been turned into regexps.
			var hit = false;

			switch (p)
			{
				case Pattern.string(v):
					if (options.nocase)
					{
						hit = f.toLowerCase() == v.toLowerCase();
					}
					else
					{
						hit = f == v;
					}

				case Pattern.matcher(ereg, _, _):
					hit = ereg.match(f);

				default:
			}

			if (!hit) return false;

			fi++;
			pi++;
		}

		// Note: ending in / means that we'll get a final ""
		// at the end of the pattern.  This can only match a
		// corresponding "" at the end of the file.
		// If the file ends in /, then it can only match a
		// a pattern that ends in /, unless the pattern just
		// doesn't have any more for it. But, a/b/ should *not*
		// match "a/b/*", even though "" matches against the
		// [^/]*? pattern, except in partial mode, where it might
		// simply not be reached yet.
		// However, a/b/ should still satisfy a/*

		// now either we fell off the end of the pattern, or we're done.
		if (fi == fl && pi == pl)
		{
			// ran out of pattern and filename at the same time.
			// an exact hit!
			return true;
		}
		else if (fi == fl)
		{
			// ran out of file, but still had pattern left.
			// this is ok if we're doing the match as part of
			// a glob fs traversal.
			return partial;
		}
		else if (pi == pl)
		{
			// ran out of pattern, still have file left.
			// this is only acceptable if we're on the very last
			// empty segment of a file with a trailing slash.
			// a/ * should match a/b/
			return (fi == fl - 1) && (file[fi] == "");
		}

		// should be unreachable.
		throw "wtf?";
	}
}
