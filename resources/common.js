window.onerror = function(message, url, line) {
	var msg = "window.onerror: [message:] " + message + "\n[url:] " + url + "\n[line:] " + line 
	logJSerr(msg)
}

function assert(fact,msg) {
	if (fact) return
	
	logJSerr( "[assertion failed] msg=" + msg )
}
function logJSerr(msg) {
    try{

	    $.ajax({
		    url: 'ajaxserver.aspx?c=x&m=' + msg , //jQuery or user-agent will urlencode
		    timeout: 2000, //ms
		    cache: false
	    });
    	
    }catch(ex){}

	firebug(msg) 
}
function firebug(s) { if (navigator.userAgent.indexOf("Firefox") > -1 && self.console) console.log(s) }

function Templatize(template, placeholderName, content) {
	var re = new RegExp("{~" + placeholderName + "~}", "g")// GLOBAL REGEX
	return template.replace( re , content ) 
}
function GetUTCHoursOffset() {
	var d = new Date()
	return  -(d.getTimezoneOffset()/60) // JS quirk +/- inversion
}

/*based on:Pretty Date (c) 2008 John Resig*/
function ElapsedDescription(msDifference){
	assert(typeof msDifference == typeof 1); assert(msDifference >= 0)
	
	var diff = (msDifference) / 1000 //secs
	var day_diff = Math.floor(diff / 86400);

	if ( isNaN(day_diff) || day_diff < 0 )  //|| day_diff > 31 )  // [orig:] day_diff >= 31 
		return;

	return day_diff == 0 && (
		diff < 60 && "just now" ||
		diff < 120 && "1 minute ago" ||
		diff < 3600 && Math.floor( diff / 60 ) + " minutes ago" ||
		diff < 7200 && "1 hour ago" ||
		diff < 86400 && Math.floor( diff / 3600 ) + " hours ago") ||
		day_diff == 1 && "yesterday" ||
		day_diff < 7 && day_diff + " days ago" ||
		//day_diff < 31 &&   [need to handle 5+ weeks ago)
		Math.ceil( day_diff / 7 ) + " weeks ago";
}
