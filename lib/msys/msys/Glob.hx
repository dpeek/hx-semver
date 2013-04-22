package msys;

using Lambda;

import msys.MiniMatch;

typedef GlobOptions = {>MiniMatchOptions,
	@:optional var cwd:String;
	@:optional var root:String;
	@:optional var maxDepth:Int;
	@:optional var maxLength:Int;
	@:optional var nomount:Bool;
	@:optional var mark:Bool;
	@:optional var sync:Bool;
	@:optional var nounique:Bool;
	@:optional var nosort:Bool;
	@:optional var silent:Bool;
	@:optional var stat:Bool;
	@:optional var globDebug:Bool;
}

// Approach:
//
// 1. Get the minimatch set
// 2. For each pattern in the set, PROCESS(pattern)
// 3. Store matches per-set, then uniq them
//
// PROCESS(pattern)
// Get the first [n] items from pattern that are all strings
// Join these together.  This is PREFIX.
//   If there is no more remaining, then stat(PREFIX) and
//   add to matches if it succeeds.  END.
// readdir(PREFIX) as ENTRIES
//   If fails, END
//   If pattern[n] is GLOBSTAR
//     // handle the case where the globstar match is empty
//     // by pruning it out, and testing the resulting pattern
//     PROCESS(pattern[0..n] + pattern[n+1 .. $])
//     // handle other cases.
//     for ENTRY in ENTRIES (not dotfiles)
//       // attach globstar + tail onto the entry
//       PROCESS(pattern[0..n] + ENTRY + pattern[n .. $])
//
//   else // not globstar
//     for ENTRY in ENTRIES (not dotfiles, unless pattern[n] is dot)
//       Test ENTRY against pattern[n+1]
//       If fails, continue
//       If passes, PROCESS(pattern[0..n] + item + pattern[n+1 .. $])
//
// Caveat:
//   Cache all stats and readdirs results to minimize syscall.  Since all
//   we ever care about is existence and directory-ness, we can just keep
//   `true` for files, and [children,...] for directories, or `false` for
//   things that don't exist.

class Glob
{
	inline static function or<T>(value:Null<T>, orValue:T):T
	{
		return value == null ? orValue : value;
	}
	
	var minimatch:MiniMatch;
	var options:Dynamic;
	// var statCache:Dynamic;
	var changedCwd:Bool;
	var root:String;
	var error:Dynamic;
	var aborted:Bool;
	var matches:Array<Dynamic>;
	var pattern:String;
	var files:Array<String>;

	var cwd:String;
	var maxDepth:Int;
	var maxLength:Int;
	var nomount:Bool;
	var dot:Bool;
	var mark:Bool;
	var sync:Bool;
	var nounique:Bool;
	var nonull:Bool;
	var nocase:Bool;
	var nosort:Bool;
	var silent:Bool;
	var stat:Bool;
	var debug:Bool;

	public function new(pattern:String, ?options:GlobOptions)
	{
		if (options == null) options = {};
		if (System.isWindows) pattern = pattern.split("\\").join("/");

		maxDepth = or(options.maxDepth, 1000);
		maxLength = or(options.maxLength, 10000);
		
		changedCwd = false;
		
		var cwd = Sys.getCwd();
		if (!Reflect.hasField(options, "cwd"))
		{
			this.cwd = cwd;
		}
		else
		{
			this.cwd = options.cwd;
			this.changedCwd = sys.FileSystem.fullPath(options.cwd) != cwd;
		}

		this.root = options.root == null ? Path.resolve([this.cwd, "/"]) : options.root;
		this.root = Path.resolve([this.root]);
		this.nomount = (options.nomount == true);

		if (pattern == null) throw "must provide pattern";

		// base-matching: just use globstar for that.
		if (options.matchBase && -1 == pattern.indexOf("/"))
		{
			if (options.noglobstar) throw "base matching requires globstar";
			pattern = "**/" + pattern;
		}

		this.dot = options.dot == true;
		this.mark = options.mark == true;
		this.sync = options.sync == true;
		this.nounique = options.nounique == true;
		this.nonull = options.nonull == true;
		this.nosort = options.nosort == true;
		this.nocase = options.nocase == true;
		this.stat = options.stat == true;
		this.debug = options.debug == true || options.globDebug == true;
		this.silent = options.silent == true;

		var mm = this.minimatch = new MiniMatch(pattern, options);
		this.options = mm.options;
		pattern = this.pattern = mm.pattern;

		this.error = null;
		this.aborted = false;

		// process each pattern in the minimatch set
		var n = this.minimatch.set.length;

		// The matches are stored as {<filename>: true,...} so that
		// duplicates are automagically pruned.
		// Later, we do an Object.keys() on these.
		// Keep them as a list so we can fill in when nonull is set.
		this.matches = [];
		
		for (i in 0...minimatch.set.length)
		{
			var pattern = minimatch.set[i];
			process(pattern, 0, i);
		}

		files = [];
		for (match in matches)
		{
			for (file in Reflect.fields(match))
			{
				files.push(file);
			}
		}
	}

	public function iterator()
	{
		return files.iterator();
	}

	function process(pattern:Array<Pattern>, depth:Int, index:Int)
	{
		// trace(depth);
		if (depth > this.maxDepth) return;

		// Get the first [n] parts of pattern that are all strings.
		var n = 0;
		for (i in 0...pattern.length)
		{
			switch (pattern[n])
			{
				case Pattern.string(_): n++;
				default: break;
			}
		}

		// now n is the index of the first one that is *not* a string.
		// see if there's anything else
		var prefix:String = null;
		
		if (n == pattern.length) // if not, then this is rather simple
		{
			prefix = MiniMatch.joinPattern(pattern);

			//need this because sys.FileSystem.exists("path\\to\\something\\") returns false on Windows..
			if ( StringTools.endsWith(prefix, '\\')  )
				prefix = prefix.substr(0, prefix.length - 1);

			if (sys.FileSystem.exists(prefix))
			{
				// either it's there, or it isn't.
				// nothing more to do, either way.
				if (prefix.charAt(0) == "/" && !nomount)
				{
					prefix = Path.join([this.root, prefix]);
				}

				this.matches[index] = this.matches[index] == null ? {} : this.matches[index];
				Reflect.setField(this.matches[index], prefix, true);
			}

			return;
		}
		else if (n == 0)
		{
			// pattern *starts* with some non-trivial item.
			// going to readdir(cwd), but not include the prefix in matches.
			prefix = null;
		}
		else
		{
			// pattern has some string bits in the front.
			// whatever it starts with, whether that's "absolute" like /foo/bar,
			// or "relative" like "../baz"
			prefix = MiniMatch.joinPattern(pattern.slice(0, n));
		}

		// get the list of entries.
		var read:String = null;
		if (prefix == null) read = ".";
		else if (isAbsolute(prefix)) read = prefix = Path.join(["/", prefix]);
		else read = prefix;

		if (!sys.FileSystem.exists(read)) return;

		// not a directory!
		// this means that, whatever else comes after this, it can never match
		if (!sys.FileSystem.isDirectory(read)) return;

		var entries = sys.FileSystem.readDirectory(read);

		// globstar is special
		if (pattern[n] == Pattern.globstar)
		{
			// test without the globstar, and with every child both below
			// and replacing the globstar.
			var s:Array<Array<Pattern>> = [pattern.slice(0, n).concat(pattern.slice(n + 1))];
			for (e in entries)
			{
				if (e.charAt(0) == "." && this.dot != true) continue;

				// instead of the globstar
				s.push(pattern.slice(0, n)
					.concat([Pattern.string(e)])
					.concat(pattern.slice(n + 1)));
				// below the globstar
				s.push(pattern.slice(0, n)
					.concat([Pattern.string(e)])
					.concat(pattern.slice(n)));
			}

			// process
			for (gsPattern in s)
			{
				process(gsPattern, depth + 1, index);
			}
		}

		// not a globstar
		// It will only match dot entries if it starts with a dot, or if
		// dot is set.  Stuff like @(.foo|.bar) isn't allowed.
		var pn = pattern[n];
		switch (pn)
		{
			case Pattern.string(v):
				var found = entries.indexOf(v) != -1;
				entries = found ? [v] : [];

			default:
				var glob = switch (pattern[n]) { case Pattern.matcher(_,_,glob): glob; default: ""; }
				var dotOk = this.dot == true || glob.charAt(0) == ".";

				entries = entries.filter(function(e) {
					if (e.charAt(0) == "." && !dotOk) return false;
					
					return switch (pattern[n])
					{
						case Pattern.string(v): e == v;
						case Pattern.matcher(ereg, _, _): ereg.match(e);
						default: false;
					}
				}).array();
		}

		// If n == pattern.length - 1, then there's no need for the extra stat
		// *unless* the user has specified "mark" or "stat" explicitly.
		// We know that they exist, since the readdir returned them.
		if (n == pattern.length - 1 &&
				!this.mark &&
				!this.stat) {
			for (e in entries)
			{
				if (prefix != null)
				{
					if (prefix != "/") e = prefix + "/" + e;
					else e = prefix + e;
				}
				
				if (e.charAt(0) == "/" && !this.nomount)
				{
					e = Path.join([this.root, e]);
				}

				this.matches[index] = this.matches[index] == null ? {} : this.matches[index];
				Reflect.setField(this.matches[index], e, true);
			}

			return;
		}

		// now test all the remaining entries as stand-ins for that part
		// of the pattern.
		if (entries.length == 0) return; // no matches possible
		for (e in entries)
		{
			var p = pattern.slice(0, n).concat([Pattern.string(e)]).concat(pattern.slice(n + 1));
			process(p, depth + 1, index);
		}
	}

	static function isAbsolute(path)
	{
		return path.charAt(0) == "/" || path == "";
	}
}

/*
function glob (pattern, options, cb) {
	if (typeof options === "function") cb = options, options = {}
	if (!options) options = {}

	var g = new Glob(pattern, options, cb)
	return g.sync ? g.found : g
}

glob.sync = globSync
function globSync (pattern, options) {
	options = options || {}
	options.sync = true
	return glob(pattern, options)
}

Glob.prototype._finish = function () {
	assert(this instanceof Glob)

	var nou = this.nounique
	, all = nou ? [] : {}

	for (var i = 0, l = this.matches.length; i < l; i ++) {
		var matches = this.matches[i]
		if (this.debug) console.error("matches[%d] =", i, matches)
		// do like the shell, and spit out the literal glob
		if (!matches) {
			if (this.nonull) {
				var literal = this.minimatch.globSet[i]
				if (nou) all.push(literal)
				else nou[literal] = true
			}
		} else {
			// had matches
			var m = Object.keys(matches)
			if (nou) all.push.apply(all, m)
			else m.forEach(function (m) {
				all[m] = true
			})
		}
	}

	if (!nou) all = Object.keys(all)

	if (!this.nosort) {
		all = all.sort(this.nocase ? alphasorti : alphasort)
	}

	if (this.mark) {
		// at *some* point we statted all of these
		all = all.map(function (m) {
			var sc = this.statCache[m]
			if (!sc) return m
			if (m.slice(-1) !== "/" && (Array.isArray(sc) || sc === 2)) {
				return m + "/"
			}
			if (m.slice(-1) === "/") {
				return m.replace(/\/$/, "")
			}
			return m
		}, this)
	}

	if (this.debug) console.error("emitting end", all)

	EOF = this.found = all
	this.emitMatch(EOF)
}

function alphasorti (a, b) {
	a = a.toLowerCase()
	b = b.toLowerCase()
	return alphasort(a, b)
}

function alphasort (a, b) {
	return a > b ? 1 : a < b ? -1 : 0
}

Glob.prototype.abort = function () {
	this.aborted = true
	this.emit("abort")
}

Glob.prototype.pause = function () {
	if (this.paused) return
	if (this.sync)
		this.emit("error", new Error("Can't pause/resume sync glob"))
	this.paused = true
	this.emit("pause")
}

Glob.prototype.resume = function () {
	if (!this.paused) return
	if (this.sync)
		this.emit("error", new Error("Can't pause/resume sync glob"))
	this.paused = false
	this.emit("resume")
}


Glob.prototype.emitMatch = function (m) {
	if (!this.paused) {
		this.emit(m === EOF ? "end" : "match", m)
		return
	}

	if (!this._emitQueue) {
		this._emitQueue = []
		this.once("resume", function () {
			var q = this._emitQueue
			this._emitQueue = null
			q.forEach(function (m) {
				this.emitMatch(m)
			}, this)
		})
	}

	this._emitQueue.push(m)

	//this.once("resume", this.emitMatch.bind(this, m))
}

Glob.prototype._stat = function (f, cb) {
	assert(this instanceof Glob)
	var abs = f
	if (f.charAt(0) === "/") {
		abs = path.join(this.root, f)
	} else if (this.changedCwd) {
		abs = path.resolve(this.cwd, f)
	}
	if (this.debug) console.error('stat', [this.cwd, f, '=', abs])
	if (f.length > this.maxLength) {
		var er = new Error("Path name too long")
		er.code = "ENAMETOOLONG"
		er.path = f
		return this._afterStat(f, abs, cb, er)
	}

	if (this.statCache.hasOwnProperty(f)) {
		var exists = this.statCache[f]
		, isDir = exists && (Array.isArray(exists) || exists === 2)
		if (this.sync) return cb.call(this, !!exists, isDir)
		return process.nextTick(cb.bind(this, !!exists, isDir))
	}

	if (this.sync) {
		var er, stat
		try {
			stat = fs.statSync(abs)
		} catch (e) {
			er = e
		}
		this._afterStat(f, abs, cb, er, stat)
	} else {
		fs.stat(abs, this._afterStat.bind(this, f, abs, cb))
	}
}

Glob.prototype._afterStat = function (f, abs, cb, er, stat) {
	var exists
	assert(this instanceof Glob)
	if (er || !stat) {
		exists = false
	} else {
		exists = stat.isDirectory() ? 2 : 1
	}
	this.statCache[f] = this.statCache[f] || exists
	cb.call(this, !!exists, exists === 2)
}

Glob.prototype._readdir = function (f, cb) {
	assert(this instanceof Glob)
	var abs = f
	if (f.charAt(0) === "/") {
		abs = path.join(this.root, f)
	} else if (isAbsolute(f)) {
		abs = f
	} else if (this.changedCwd) {
		abs = path.resolve(this.cwd, f)
	}

	if (this.debug) console.error('readdir', [this.cwd, f, abs])
	if (f.length > this.maxLength) {
		var er = new Error("Path name too long")
		er.code = "ENAMETOOLONG"
		er.path = f
		return this._afterReaddir(f, abs, cb, er)
	}

	if (this.statCache.hasOwnProperty(f)) {
		var c = this.statCache[f]
		if (Array.isArray(c)) {
			if (this.sync) return cb.call(this, null, c)
			return process.nextTick(cb.bind(this, null, c))
		}

		if (!c || c === 1) {
			// either ENOENT or ENOTDIR
			var code = c ? "ENOTDIR" : "ENOENT"
			, er = new Error((c ? "Not a directory" : "Not found") + ": " + f)
			er.path = f
			er.code = code
			if (this.debug) console.error(f, er)
			if (this.sync) return cb.call(this, er)
			return process.nextTick(cb.bind(this, er))
		}

		// at this point, c === 2, meaning it's a dir, but we haven't
		// had to read it yet, or c === true, meaning it's *something*
		// but we don't have any idea what.  Need to read it, either way.
	}

	if (this.sync) {
		var er, entries
		try {
			entries = fs.readdirSync(abs)
		} catch (e) {
			er = e
		}
		return this._afterReaddir(f, abs, cb, er, entries)
	}

	fs.readdir(abs, this._afterReaddir.bind(this, f, abs, cb))
}

Glob.prototype._afterReaddir = function (f, abs, cb, er, entries) {
	assert(this instanceof Glob)
	if (entries && !er) {
		this.statCache[f] = entries
		// if we haven't asked to stat everything for suresies, then just
		// assume that everything in there exists, so we can avoid
		// having to stat it a second time.  This also gets us one step
		// further into ELOOP territory.
		if (!this.mark && !this.stat) {
			entries.forEach(function (e) {
				if (f === "/") e = f + e
				else e = f + "/" + e
				this.statCache[e] = true
			}, this)
		}

		return cb.call(this, er, entries)
	}

	// now handle errors, and cache the information
	if (er) switch (er.code) {
		case "ENOTDIR": // totally normal. means it *does* exist.
			this.statCache[f] = 1
			return cb.call(this, er)
		case "ENOENT": // not terribly unusual
		case "ELOOP":
		case "ENAMETOOLONG":
		case "UNKNOWN":
			this.statCache[f] = false
			return cb.call(this, er)
		default: // some unusual error.  Treat as failure.
			this.statCache[f] = false
			if (this.strict) this.emit("error", er)
			if (!this.silent) console.error("glob error", er)
			return cb.call(this, er)
	}
}

var isAbsolute = process.platform === "win32" ? absWin : absUnix

function absWin (p) {
	if (absUnix(p)) return true
	// pull off the device/UNC bit from a windows path.
	// from node's lib/path.js
	var splitDeviceRe =
				/^([a-zA-Z]:|[\\\/]{2}[^\\\/]+[\\\/][^\\\/]+)?([\\\/])?/
		, result = splitDeviceRe.exec(p)
		, device = result[1] || ''
		, isUnc = device && device.charAt(1) !== ':'
		, isAbsolute = !!result[2] || isUnc // UNC paths are always absolute

	return isAbsolute
}

function absUnix (p) {
	return p.charAt(0) === "/" || p === ""
}
*/
