package semver;

using StringTools;
using Lambda;
using semver.SemVer.StringHelper;

/**
See http://semver.org/
This implementation is a *hair* less strict in that it allows v1.2.3 things, 
and also tags that don't begin with a char.
*/
class SemVer
{
	static var semver = 
			"\\s*[v=]*\\s*([0-9]+)"				// major
		   + "\\.([0-9]+)"						// minor
		   + "\\.([0-9]+)"						// patch
		   + "(-[0-9]+-?)?"						// build
		   + "([a-zA-Z-+][a-zA-Z0-9-\\.:]*)?";	// tag

	static var exprComparator = "^((<|>)?=?)\\s*(" + semver + ")$|^$";

	static var xRangePlain =
		"[v=]*([0-9]+|x|X|\\*)"
		+ "(?:\\.([0-9]+|x|X|\\*)"
		+ "(?:\\.([0-9]+|x|X|\\*)"
		+ "([a-zA-Z-][a-zA-Z0-9-\\.:]*)?)?)?";

	static var xRange = "((?:<|>)=?)?\\s*" + xRangePlain;

	static var exprSpermy = "(?:~>?)" + xRange;

	public static var parse = new EReg("^\\s*" + semver + "\\s*$", "");
	public static var parsePackage = new EReg("^\\s*([^\\/]+)[-@](" +semver+")\\s*$", "");
	public static var parseRange = new EReg("^\\s*(" + semver + ")\\s+-\\s+(" + semver + ")\\s*$", "");
	public static var validComparator = new EReg("^"+exprComparator+"$", "");
	public static var parseXRange = new EReg("^"+xRange+"$", "");
	public static var parseSpermy = new EReg("^"+exprSpermy+"$", "");
	public static var rangeReplace = ">=$1 <=$7";

	public static function parseString(version:String):Array<String>
	{
		var match = parse.match(version);
		if (!match) return null;
		
		var v = [];
		v[0] = parse.matched(1);
		v[1] = parse.matched(2);
		v[2] = parse.matched(3);
		v[3] = parse.matched(4);
		v[4] = parse.matched(5);
		return v;
	}

	static function stringify(version:Array<String>)
	{
		var v = version.copy();
		for (i in 0...v.length) v[i] = v[i] == null ? "" : v[i];
		return [v[0], v[1], v[2]].join(".") + (v[3]) + (v[4]);
	}	

	public static function clean(version:String):String
	{
		var v = parseString(version);
		if (v == null) return null;
		return stringify(v);
	}

	public static function valid(version:String):Bool
	{
		return parseString(version) != null && ~/^[v=]+/.replace(StringTools.trim(version), "") != "";
	}

	public static function validPackage(version:String):Bool
	{
		return parsePackage.match(version) && StringTools.trim(version) != "";
	}

	// range can be one of:
	// "1.0.3 - 2.0.0" range, inclusive, like ">=1.0.3 <=2.0.0"
	// ">1.0.2" like 1.0.3 - 9999.9999.9999
	// ">=1.0.2" like 1.0.2 - 9999.9999.9999
	// "<2.0.0" like 0.0.0 - 1.9999.9999
	// ">1.0.2 <2.0.0" like 1.0.3 - 1.9999.9999
	static var starExpression = ~/(<|>)?=?\s*\*/g;
	static var starReplace = "";
	static var compTrimExpression = new EReg("((<|>)?=?)\\s*("+semver+"|"+xRangePlain+")", "g");
	static var compTrimReplace = "$1$3";

	public static function toComparators(range:String):Array<Array<String>>
	{
		var ret = range.trim()
			.replaceEReg(parseRange, rangeReplace)
			.replaceEReg(compTrimExpression, compTrimReplace)
			.splitEReg(~/\s+/)
			.join(" ")
			.split("||")
			.map(function(orchunk:String) {
			  return orchunk
				.split(" ")
				.map(replaceXRanges)
				.map(replaceSpermies)
				.map(replaceStars)
				.join(" ")
				.trim();
			})
			.map(function(orchunk:String) {
			  return orchunk
				.trim()
				.splitEReg(~/\s+/)
				.filter(function (c) { return validComparator.match(c); })
				.array();
			})
			.filter(function (c) { return c.length > 0; })
			.array();
		return ret;
	}

	public static function replaceStars(stars:String):String
	{
		return stars.trim().replaceEReg(starExpression, starReplace);
	}

	// "2.x","2.x.x" --> ">=2.0.0- <2.1.0-"
	// "2.3.x" --> ">=2.3.0- <2.4.0-"
	static function replaceXRanges(ranges:String):String
	{
		return ranges.splitEReg(~/\s+/)
					 .map(replaceXRange)
					 .join(" ");
	}

	static function replaceXRange(version:String):String
	{
		version = version.trim();
		version = parseXRange.customReplace(version, function(ereg:EReg):String
		{
			var v = ereg.matched(0);
			var gtlt = ereg.matched(1);
			var M = ereg.matched(2);
			var m = ereg.matched(3);
			var p = ereg.matched(4);
			var t = ereg.matched(5);

			var anyX = M == null || M.toLowerCase() == "x" || M == "*"
					|| m == null || m.toLowerCase() == "x" || m == "*"
					|| p == null || p.toLowerCase() == "x" || p == "*";
			var ret = v;

			if (gtlt != null && anyX)
			{
				// just replace x'es with zeroes
				if (M == null || M == "*" || M.toLowerCase() == "x") M = "0";
				if (m == null || m == "*" || m.toLowerCase() == "x") m = "0";
				if (p == null || p == "*" || p.toLowerCase() == "x") p = "0";
				ret = gtlt+M+"."+m+"."+p+"-";
			}
			else if (M == null || M == "*" || M.toLowerCase() == "x")
			{
				ret = "*"; // allow any
			}
			else if (m == null || m == "*" || m.toLowerCase() == "x")
			{
				// append "-" onto the version, otherwise
				// "1.x.x" matches "2.0.0beta", since the tag
				// *lowers* the version value
				ret = ">="+M+".0.0- <"+(Std.parseInt(M)+1)+".0.0-";
			}
			else if (p == null || p == "*" || p.toLowerCase() == "x")
			{
				ret = ">="+M+"."+m+".0- <"+M+"."+(Std.parseInt(m)+1)+".0-";
			}

			return ret;
		});
		
		return version;
	}

	// ~, ~> --> * (any, kinda silly)
	// ~2, ~2.x, ~2.x.x, ~>2, ~>2.x ~>2.x.x --> >=2.0.0 <3.0.0
	// ~2.0, ~2.0.x, ~>2.0, ~>2.0.x --> >=2.0.0 <2.1.0
	// ~1.2, ~1.2.x, ~>1.2, ~>1.2.x --> >=1.2.0 <1.3.0
	// ~1.2.3, ~>1.2.3 --> >=1.2.3 <1.3.0
	// ~1.2.0, ~>1.2.0 --> >=1.2.0 <1.3.0
	static function replaceSpermies(version:String):String
	{
		version = version.trim();
		version = parseSpermy.customReplace(version, function(ereg:EReg):String
		{
			var v = ereg.matched(0);
			var gtlt = ereg.matched(1);
			var M = ereg.matched(2);
			var m = ereg.matched(3);
			var p = ereg.matched(4);
			var t = ereg.matched(5);

			if (gtlt != null) throw "Using '" + gtlt + "' with ~ makes no sense. Don't do it.";
			if (M == null || M.toLowerCase() == "x") return "";

			// ~1 == >=1.0.0- <2.0.0-
			if (m == null || m.toLowerCase() == "x")
			{
				return ">="+M+".0.0- <"+(Std.parseInt(M)+1)+".0.0-";
			}

			// ~1.2 == >=1.2.0- <1.3.0-
			if (p == null || p.toLowerCase() == "x")
			{
				return ">="+M+"."+m+".0- <"+M+"."+(Std.parseInt(m)+1)+".0-";
			}

			// ~1.2.3 == >=1.2.3- <1.3.0-
			t = t.or("-");
			return ">="+M+"."+m+"."+p+t+" <"+M+"."+(Std.parseInt(m)+1)+".0-";
		});

		return version;
	}

	public static function validRange(range:String):String
	{
	  range = replaceStars(range);
	  var c = toComparators(range);
	  return (c.length == 0)
		   ? null
		   : c.map(function (c) { return c.join(" "); }).join("||");
	}

	// returns the highest satisfying version in the list, or undefined
	public static function maxSatisfying(versions:Array<String>, range:String):String
	{
		versions =  versions
			.filter(function(v) { return satisfies(v, range); })
			.array();
		versions.sort(compare);
		return versions.pop();
	}

	public static function satisfies(version:String, range:String):Bool
	{
		if (!valid(version)) return false;
		var comparitors = toComparators(range);

		for (set in comparitors)
		{
			var ok = false;
			for (r in set)
			{
				var gtlt = r.charAt(0) == ">"
						 ? gt
						 : r.charAt(0) == "<" ? lt
						 : null;
				var eq = r.charAt((gtlt == null ? 0 : 1)) == "=";
				var sub = (eq?1:0) + (gtlt==null?0:1);
				
				if (gtlt == null) eq = true;
				var r = r.substr(sub);

				// r = (r == "") ? r : (valid(r) == null ? "" : r);
				ok = (r == "") || (eq && r == version);
				if (!ok && gtlt != null)
				{
					var res = gtlt(version, r);
					ok = (res == true || res == null);
				}
				if (!ok) break;
			}

			if (ok) return true;
		}

		return false;
	}

	// return v1 > v2 ? 1 : -1
	static function compare(v1:String, v2:String):Int
	{
		var g = gt(v1, v2);
		return g == null ? 0 : (g ? 1 : -1);
	}

	static function rcompare(v1:String, v2:String):Int
	{
		return compare(v2, v1);
	}

	public static function lt(v1:String, v2:String)
	{
		return gt(v2, v1);
	}
	
	public static function gte(v1:String, v2:String)
	{
		return !lt(v1, v2);
	}
	
	public static function lte(v1:String, v2:String)
	{
		return !gt(v1, v2);
	}
	
	public static function eq(v1:String, v2:String)
	{
		return gt(v1, v2) == null;
	}

	public static function neq(v1:String, v2:String)
	{
		return gt(v1, v2) != null;
	}

	public static function cmp(v1:String, c:String, v2:String):Bool
	{
		return switch(c)
		{
			case ">":  gt(v1, v2);
			case "<": lt(v1, v2);
			case ">=": gte(v1, v2);
			case "<=": lte(v1, v2);
			case "==": eq(v1, v2);
			case "!=": neq(v1, v2);
			case "===": v1 == v2;
			case "!==": v1 != v2;
		}
	}

	static function num(v:String):Int
	{
		return v == null ? -1 : Std.parseInt(~/[^0-9]+/g.replace(v, ""));
	}

	public static function gt(version1:String, version2:String):Null<Bool>
	{
		var v1 = parseString(version1);
		var v2 = parseString(version2);

		if (v1 == null || v2 == null) return false;
		
		for (i in 0...4)
		{
			var p1 = num(v1[i]);
			var p2 = num(v2[i]);
			// trace(p1 + " > " + p2);
			if (p1 > p2) return true;
			else if (p1 != p2) return false;
		}

		// no tag is > than any tag, or use lexicographical order.
		var tag1 = v1[4];
		var tag2 = v2[4];
		
		// kludge: null means they were equal.  falsey, and detectable.
		// embarrassingly overclever, though, I know.
		return tag1 == tag2 ? null
			 : tag1 == null ? true
			 : tag2 == null ? false
			 : tag1 > tag2;
	}

	public static function inc(version:String, release:Release)
	{
		var parsed = parseString(version);
		if (parsed == null) return null;

		var incIndex = Type.enumIndex(release);
		var current = num(parsed[incIndex]);
		parsed[incIndex] = Std.string(current == -1 ? 1 : current + 1);

		for (i in incIndex + 1...4)
		{
			if (num(parsed[i]) != -1) parsed[i] = "0";
		}

		if (parsed[3] != null) parsed[3] = "-" + parsed[3];
		parsed[4] = "";

		return stringify(parsed);
	}
}

enum Release
{
	Major;
	Minor;
	Patch;
	Build;
}

class StringHelper
{
	public static function replaceEReg(string:String, replace:EReg, by:String):String
	{
		return replace.replace(string, by);
	}

	public static function splitEReg(string:String, delimiter:EReg):Array<String>
	{
		return delimiter.split(string);
	}

	public static function or(string:String, substitute:String):String
	{
		return string == null ? substitute : string;
	}
}
