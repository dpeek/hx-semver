function autoResize(id, size)
{
	if(!id) id = "api";

	// var ref = parent;
	// while(ref != null && ref.parent != null)
	// {
	// 	ref = ref.parent;
		
	// }
	var api = top.document.getElementById(id);

	if(api != null) api.height = size;
}

function onPageLoad(title, path)
{
	autoResize("api", document.body.clientHeight);

	if (location.href.indexOf('is-external=true') == -1) {
		top.document.title = title;
	}

	if(history.pushState)
	{
		top.history.replaceState(null, top.document.title, '#'+path);
	}
	else
	{
		top.location.hash = path;
	}

	var size = Math.max(document.body.scrollHeight, parent.frames[0].document.body.scrollHeight);

	autoResize("api", size);
}

function showInherited(name, visibile) {
	//if IE
	// document.styleSheets[0].rules
	var r = document.styleSheets[0].cssRules;
	if(r == undefined) {
		document.styleSheets[0].addRule(".hideInherited" + name, visibile ? "display:inline" : "display:none");
		document.styleSheets[0].addRule(".showInherited" + name, visibile ? "display:none" : "display:inline");
	}
	else {
		for (var i = 0; i < r.length; i++) {
			if (r[i].selectorText == ".hideInherited" + name)
				r[i].style.display = visibile ? "inline" : "none";
			if (r[i].selectorText == ".showInherited" + name)
				r[i].style.display = visibile ? "none" : "inline";
		}
	}

	setCookie(
		"showInherited" + name,
		visibile ? "true" : "false",
		10000,
		"/",
		document.location.domain);
}

function initShowInherited() {
    showInherited("Var", getCookie("showInheritedVar") == "true");
    showInherited("Method", getCookie("showInheritedMethod") == "true");
}

function setCookie(name, value, days, path, domain, secure) {
	var endDate=new Date();
	endDate.setDate(endDate.getDate() + days);

	document.cookie =
		name + "=" + escape(value) +
		((days==null) ? "" : ";expires=" + endDate.toGMTString()) +
        ((path) ? "; path=" + path : "") +
        ((domain) ? "; domain=" + domain : "") +
        ((secure) ? "; secure" : "");
}

function getCookie(name) {
	if (document.cookie.length>0) {
		begin=document.cookie.indexOf(name + "=");
		if (begin != -1) {
			begin = begin + name.length + 1;
			end = document.cookie.indexOf(";",begin);
			if(end==-1)
				end=document.cookie.length;
			return unescape(document.cookie.substring(begin,end));
		}
	}
	return "";
}

function isIE() {
	if(navigator.appName.indexOf("Microsoft") != -1)
		return true;
	return false;
}

initShowInherited();

/* Smooth scrolling
   Changes links that link to other parts of this page to scroll
   smoothly to those links rather than jump to them directly, which
   can be a little disorienting.
   
   sil, http://www.kryogenix.org/
   
   v1.0 2003-11-11
   v1.1 2005-06-16 wrap it up in an object
*/

function scrollToAnchor(name)
{
	var links = document.getElementsByTagName("a");

	var i = 0;

	while(links.length > i)
	{
		var link = links[i];
		if(link.name == name)
		{	
			ss.smoothScroll(link);
		}
		i++;
	}
}

var ss = {
 

  smoothScroll: function(destinationLink)
  {

    
  
    // Find the destination's position
    var destx = destinationLink.offsetLeft; 
    var desty = destinationLink.offsetTop;
    var thisNode = destinationLink;
    while (thisNode.offsetParent && 
          (thisNode.offsetParent != document.body)) {
      thisNode = thisNode.offsetParent;
      destx += thisNode.offsetLeft;
      desty += thisNode.offsetTop;
    }
  
    // Stop any current scrolling
    clearInterval(ss.INTERVAL);
  
    cypos = ss.getCurrentYPos();
  
    ss_stepsize = parseInt((desty-cypos)/ss.STEPS);
    ss.INTERVAL =
setInterval('ss.scrollWindow('+ss_stepsize+','+desty+',"'+destinationLink.name+'")',10);
  
  },

  scrollWindow: function(scramount,dest,anchor) {
    wascypos = ss.getCurrentYPos();
    isAbove = (wascypos < dest);
    top.scrollTo(0,wascypos + scramount);
    iscypos = ss.getCurrentYPos();
    isAboveNow = (iscypos < dest);
    if ((isAbove != isAboveNow) || (wascypos == iscypos)) {
      // if we've just scrolled past the destination, or
      // we haven't moved from the last scroll (i.e., we're at the
      // bottom of the page) then scroll exactly to the link
      top.scrollTo(0,dest);
      // cancel the repeating timer
      clearInterval(ss.INTERVAL);
      // and jump to the link directly so the URL's right
      location.hash = anchor;
    }
  },

  getCurrentYPos: function() {
    if (top.document.body && top.document.body.scrollTop)
      return top.document.body.scrollTop;
    if (top.document.documentElement && top.document.documentElement.scrollTop)
      return top.document.documentElement.scrollTop;
    if (top.pageYOffset)
      return top.pageYOffset;
    return 0;
  },

}
ss.STEPS = 25;


