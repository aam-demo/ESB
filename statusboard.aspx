<%@ Page Language="VB" %>

<script runat="server">
	
	ReadOnly Property HeadInject() As String ' execs after Page_Load
		Get
			' NOTE: status info is pulled direct from db (not cached)
			' NOTE: top.empStatus[] is modified by ajax/xhr eval() ; explicitly specify "top" scope/container 
			
			Dim jsLines As String = _
			 "var minutesAJAXStatusUpdate=" & AppSettings.minutesBrowserAJAXUpdateInterval & Environment.NewLine & _
			 "var statusTableHeader=" & Tools.JavaScriptSafe(App.GetTemplate("StatusTable"), True) & _
			 "var mtRow=" & Tools.JavaScriptSafe(App.GetTemplate("StatusTableEmployeeRow"), True) & _
			 "var blankEditLayer=" & Tools.JavaScriptSafe(App.GetTemplate("setStatusEditLayerTemplate"), True) & _
			 "var empData=[]; top.empStatus=[];" & Environment.NewLine & _
			 JSOutput.InitialEmployeeData() & _
			 JSOutput.StatusUpdate(Nothing, False)

			Dim s As String = String.Concat("<", "SCRIPT>", jsLines, "</", "SCRIPT>")

			Return s
		End Get
	End Property
	
	Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs)
		App.ExceptionIfNotInitialized()
		
		If Tools.StrContains(Request.Url, "minimode=1") Then
			' is minimode
			Me.megamodeFOOTER.Visible = False
			Me.megamodeHEADER.Visible = False
			Me.megamodeTABS.Visible = False
			'			Me.MiniModeButton.Visible = True
		End If

		If Page.IsPostBack Then
			HandleEmployeeStatusChange()
		End If

	End Sub

	''' <summary>
	''' HANDLE FORM SUBMISSION - USER PUNCH
	''' </summary>
	'''
	Private Sub HandleEmployeeStatusChange()

		Dim utcHoursOffsetStr As String = Request.Form("utcHoursOffset")		' -7 for PDT, -9 for Anchorage (?), etc. etc.
		Dim utcHoursOffset As Integer = CInt(utcHoursOffsetStr) : Assert.True(utcHoursOffset >= -12 And utcHoursOffset <= 14) ' valid range = -12 to +14
		
		Dim utcNow As DateTime = Now.ToUniversalTime
		Dim ticksTimestamp As Long = utcNow.Ticks
		' assumption: webapp's CLR appdomain runs in one CPU core in one physical machine - the ticks value will always be unique
		' otherwise, could let db create Now-time with corresponding ticks representation; or could synchronize this code-block
		
		Dim emplIDStr As String = Request.Form("eID")
		Dim emplID As Short = CShort(emplIDStr) : Assert.True(Business.EmployeeID.IsValidEmpID(emplID))
		
		'If Not Business.UserLocation.CanAcceptPunchFromTimezone(emplID, utcHoursOffset) _
		' AndAlso Not App.IsDevMachine Then

		'	App.Log(String.Format("Not Business.LocationTimezone.CanAcceptPunchFromTimezone: {0}, {1}", emplID, utcHoursOffset))
		'	GoTo punchComplete

		'End If
		
		
		Dim punchtype As Byte = CByte(Request.Form("punchtype")) ' let exception on byte-conversion blow up
		Dim commentsStr As String = Tools.SuperTrim(Request.Form("commenttext"))
		Dim returntextStr As String = Tools.SuperTrim(Request.Form("returntext"))

		Using dc As ESBdb.EmployeeStatus = DataMgr.NewDataContext
			Try
				
				dc.INSERT_EMPLOYEE_PUNCH(emplID, punchtype, utcNow, utcHoursOffset, ticksTimestamp, App.CurrentRemoteIP, commentsStr, returntextStr)
				' implicit punchtype validation (FOREIGN KEY)
				' allow possible auto silent truncation of string fields (fullname , phone_number ...)

			Catch ex As Exception
				App.Log(ex)

			End Try
		End Using

punchComplete:
		Response.Redirect(Request.Url.ToString, True) ' move past FORM submission; so user can F5 Refresh without warning popup
	End Sub
	
</script>

<html>
<head>
<TITLE>RIM Employee Status Board</TITLE>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<link href="resources/ESB.css" rel="stylesheet" type="text/css">
<script src="resources/jquery-1.2.6.pack.js" type="text/javascript"></script>
<script src="resources/jQueryCookie.js" type="text/javascript"></script>
<%--<script src="resources/dateJS-2008-05-13.js" type="text/javascript"></script>--%>
<script src="resources/common.js" type="text/javascript"></script>
<script>
function KioskButton() {
	if (self.location== top.location) return "" //not IFRAME'd
	return "<A href=" + location.href + "?minimode=1 target=nxWin><IMG src='resources/images/explode_window.gif' ></A>"
}
</script>
<%= HeadInject %>
</head>

<body style="margin-left:10px; margin-right:15px;">

<div>
<%-- #############--%>

<asp:PlaceHolder ID=megamodeHEADER runat=server>

	<table width=100%><tr>
	<td style="font-weight:bold; font-size:16pt; color:#485889" nowrap>
		<img src="resources/images/app_logo.gif" style="vertical-align:middle; margin:3">
			Employee Status Board
	</td>
	
	<td align=right>
			<script> document.write( KioskButton() ) </script>
		
	</td>
	</tr>
	</table>

</asp:PlaceHolder>

<%-- #############--%>

<table width=100%><tr valign=bottom>
<td>

<asp:PlaceHolder ID=megamodeTABS runat=server>

	<div id="locTabs">
	<div id=1>California</div>
	<div id=2>Maryland</div>
	<div id=3>Ireland</div>
	<div id=4>Guam</div>
	<div id=5>Hawaii</div>
	</div>

	<div id="orgTabs" style="display:none">
	<div id=1>London</div>
	<div id=2>Buffalo</div>
	<div id=3>Santa Cruz</div>
	</div>

</asp:PlaceHolder>

<%--<asp:PlaceHolder ID=MiniModeButton runat=server Visible=false>
	<input type=button id=MiniModeSwitch 
		onclick="location=location.href.replace( /[?]minimode=1/ , ''); return false" value="Mega Mode">
</asp:PlaceHolder>
--%>
</td>

<td align=right >
	<div id=lastUpdate style="font-size:9pt;padding-right:20px; padding-bottom:7px"></div>
</td>

<td align=right>
	<div style="margin-bottom:7px">
	
			<table cellpadding=2 cellspacing=0 class=TopLegend><tr>
			<%--<tr><td nowrap style="color:white; font-weight:bold">Legend</td></tr>--%>
			<td class=StatusIn style="border:1px solid black">IN</td>
			<td>&nbsp;</td>
			<td class=StatusUnavailable style="border:1px solid black">UNAVAIL</td>
			<td>&nbsp;</td>
			<td class=StatusOut style="border:1px solid black">OUT</td></tr>
		</table>
		
	</div>
</td>
</tr></table>

<%-- #############--%>
<div id="statusTable"></div>

<%-- #############--%>
<div id="statusEditPopup"></div>

<%-- #############--%>
<div id="empInfoTooltip" 
	style="visibility:hidden; position:absolute; z-index:100; width:230; background-color:cyan; border:1px solid #fdfdfd; padding:2px"></div>

<%-- #############--%>
<div id="empInfoPopup" 
	style="visibility:hidden; position:absolute; z-index:100; width:400; overflow:auto; background-color:Cyan; border: 2px solid black; padding:4px"></div>

<%-- #############--%>
<form id="form1" runat="server">
<input type=hidden id=utcHoursOffset name=utcHoursOffset>
<input type=hidden id=eID name=eID>
<input type=hidden id=punchtype name=punchtype>
<input type=hidden id=returntext name=returntext>
<input type=hidden id=commenttext name=commenttext>
</form>

<%-- #############--%>
<asp:PlaceHolder ID=megamodeFOOTER runat=server>

<table width=100% style="margin-top:30px">
<tr valign=top>
<TD>
	<%-- heightmaker: for edit popup--%>
	<div style="width:1;height:170px"></div>
</TD>

<td align=right >

	<img src=resources/images/acrobat.gif align=baseline> 
	<a onclick="return false" href="user_guide_end-user_mode.pdf" target=newHW001>Help</a>

	<div style="font-size:8pt"><%=App.versionDescription%></div>
	
	<div style="font-weight:bold"
		><a href="mailto:dev@demo-corp.com?Subject=Status Board Bug">report bugs</a></div>

</td>
</tr></table>

</asp:PlaceHolder>

</div>

</body>
</html>

<script>
var currLocTab = '', currOrgTab = '', empRowEditing = '' ; var isMini = (location.href.indexOf("minimode=1") >-1)
PageInit()

function PageInit() {
	if (!top.ttimestamp) firebug("blank ttimestamp")

	setInterval("GetUpdates()", 1000 * 60 * minutesAJAXStatusUpdate)//x minutes	

	$(document).click(function(event) { // empl info popup clickaway-close

		if (event.target.id &&
			(event.target.id.indexOf("infoTrigger") == 0 || event.target.id == "emplInfoEmailLink"))
			return
		//event-target not popup-trigger or email-mailto link, hide popup-layer			
		HideEmpInfoPopup()
	})

	//tab stuff
	$("#locTabs DIV")
		.attr("class", "loc")
		.mouseover(function() { $(this).addClass("locHover"); })
		.mouseout(function() { $(this).removeClass("locHover"); })
		.click(function() { locTabClick($(this).get(0).id) });

	$("#orgTabs DIV")
		.attr("class", "org")
		.mouseover(function() { $(this).addClass("orgHover"); })
		.mouseout(function() { $(this).removeClass("orgHover"); })
		.click(function() { orgTabClick($(this).get(0).id) });

	var tabInCookie = $.cookie('esbTab')
	if (tabInCookie) {

		var parts = tabInCookie.split(":")
		var ckLoc = parts[0]
		var ckOrg = (parts.length > 1) ? parts[1] : ''

		if (ckLoc) {
			if (ckOrg) SelectOrgTab(ckOrg) //always select; execution-order for cookiesetting	(cookieVal = currLocTab + ":" + currOrgTab)

			if (isMini) { //no tabs in minimode
				SelectLocTab(ckLoc)
				RewriteTable()
			}
			else {
				locTabClick($("#locTabs #" + ckLoc).get(0).id)
			}
		}
	} else {// no tabInCookie; demo defaults	
		SelectLocTab(1)
		SelectOrgTab(1)
		//orgTabClick(1)
		locTabClick(1) 
		//	SelectOrgTab(1)		SelectLocTab(1)
		//	SetTabInCookie() 		RewriteTable()
	}

}
function RewriteTable() {

	/*constants*/var re1 = new RegExp("<" + "!--", "g"); var re2 = new RegExp("-->", "g")
	
	var accum = statusTableHeader
	//minimode has no COMMENTS column (default); so if NOT minimode...
	if (!isMini) accum = accum.replace(re1, "").replace(re2, "")
	
	for (eID in empData) {
		var edata = empData[eID]

		if (edata.homeLoc == currLocTab &&
			(currLocTab != 1 || edata.homeOrg == currOrgTab)) { //loc:1=Alaska	

			//			empData['{~emplID~}']={name:{~name~}, phone:{~phone~},homeLoc:{~homeLoc~},homeOrg:{~homeOrg~}}
			//			top.empStatus['{~emplID~}']={punch:{~punchtype~}, comment:{~comment~}, returntext:{~returntext~} } whenpunched

			var statusComment = '', statusReturn = ''
			var status = new GetEmpStatus(eID) //default=OUT

			if (top.empStatus[eID]) {
				statusComment = top.empStatus[eID].comment
				statusReturn = top.empStatus[eID].returntext
			}

			var btnVal = 'set' //default							// \\old ----------if (status.isOut) btnVal = "-IN-"

			var row = mtRow		//indicatorClass | {~EmployeeName~} {~PhoneNumber~} {~ID~} {~comments~} {~return~}
			row = Templatize(row, "ID", eID)
			row = Templatize(row, "EmployeeName", edata.name)
			row = Templatize(row, "PhoneNumber", edata.phone)
			row = Templatize(row, "comments", statusComment)
			row = Templatize(row, "returntext", statusReturn)
			row = Templatize(row, "indicatorClass", status.indicatorClass)
			row = Templatize(row, "btnVALUE", btnVal)

			//minimode has no COMMENTS column (default); so if NOT minimode...
			if (!isMini) row = row.replace(re1, "").replace(re2, "")

			accum += row + "\n"
		}
	}
	$('#statusTable').html(accum)

}
function HandleStatusEdit(eID) {
	assert(eID, "#40101")
		
	var oTrigger = $("#setTrigger" + eID).get(0)

	/*constant*/var btnTemplate =
		'<input type=button value="{~btnVALUE~}" onclick="SetStatusSubmit(this); return false" style="padding:3px 7px">'
	
	//always CANCEL prior being-edited (for SET other or CANCEL self)
	var priorEditingID = empRowEditing
	CancelStatusEdit() //zaps empRowEditing 
	if (priorEditingID == eID) return //CANCEL edit

	empRowEditing = eID //now editing this emp ID
	
	oTrigger.value = "cancel" //trigger msg

	var jq = $(".statusRow[id=" + eID + "]"); assert(jq, "#50644")
	var triggerOffset = jq.offset()		
	var editlayer = $("#statusEditPopup").get(0)

	layerHTML = blankEditLayer
	layerHTML = Templatize( layerHTML , "commentsTitle", CommentDefaultText())	
	layerHTML = Templatize( layerHTML , "returnTitle", ReturnDefaultText())

	// set buttons
	var btn1 = '', btn2 = '', btn3 = ''	
	var status = new GetEmpStatus(eID)

	if (status.isIn) {
		btn2 = Templatize(btnTemplate, "btnVALUE", "OUT")
		btn3 = Templatize(btnTemplate, "btnVALUE", "UNAVAIL.")
	}
	if (status.isOut) {
		btn1 = Templatize(btnTemplate, "btnVALUE", "IN") + "<hr noshade>"
		btn3 = Templatize(btnTemplate, "btnVALUE", "UNAVAIL.")
	}
	if (status.isUnavail) {
		btn1 = Templatize(btnTemplate, "btnVALUE", "IN") + "<hr noshade>"
		btn2 = Templatize(btnTemplate, "btnVALUE", "OUT")
	}
	layerHTML = Templatize(layerHTML, "btn1", btn1)
	layerHTML = Templatize(layerHTML, "btn2", btn2)
	layerHTML = Templatize(layerHTML, "btn3", btn3)

	editlayer.innerHTML = layerHTML 
	
	var edata = empData[eID]
	$("SPAN[id=editname]").html(edata.name) //<span id=editname></span>

	editlayer.style.top = triggerOffset.top + jq.get(0).offsetHeight - 3
	editlayer.style.left = triggerOffset.left + 5
	editlayer.style.visibility = "visible"

}
function SetStatusSubmit(oBtn) {
	assert(oBtn, "#80080")
	assert(empRowEditing, "#44344")

	var btnVal = oBtn.value

	var punchtype		//1Out, 2In, 3Unavail - punchtypes
	if (btnVal == "IN") punchtype = 2
	if (btnVal == "OUT") punchtype = 1
	if (btnVal == "UNAVAIL.") punchtype = 3
	assert(punchtype, "#421099")

	SubmitStatus(empRowEditing, $("#inputEditReturn").get(0).value , $("#inputEditComments").get(0).value, punchtype)
}
function SubmitStatus(emplID, returntext, commentstext, punchtype) {

	//FORM id="form1" id=eID <input type=hidden id=punchtype name=punchtype> <input type=hidden id=returntext name=returntext><input type=hidden id=commenttext name=commenttext>
	assert(punchtype, "#421099")
	assert(emplID, "#4170544")

	$("FORM[id=form1] #utcHoursOffset").get(0).value = GetUTCHoursOffset()
	$("FORM[id=form1] #eID").get(0).value = emplID
	$("FORM[id=form1] #returntext").get(0).value = returntext
	$("FORM[id=form1] #commenttext").get(0).value = commentstext
	$("FORM[id=form1] #punchtype").get(0).value = punchtype

	document.forms[0].submit()
}
function GetEmpStatus(eID) {//ctor
	assert(eID, "#43336")
	
	//default=OUT	
	this.indicatorClass = "StatusOut"
	this.description = "OUT"
	this.isOut = true; this.isUnavail = false; this.isIn = false 
	
	if (top.empStatus[eID] && top.empStatus[eID].punch) {
		//1Out, 2In, 3Unavail - punchtypes
		var empPunch = top.empStatus[eID].punch

		if (empPunch == 2) {//IN
			this.isIn = true; this.isOut = false
			this.indicatorClass = "StatusIn"
			this.description = "IN"
		}
		if (empPunch == 3) {//UNAVAIL
			this.isUnavail = true; this.isOut = false
			this.indicatorClass = "StatusUnavailable"
			this.description = "UNAVAIL."
		}
	}
}
function HideEmpInfoPopup() {
	$("#empInfoPopup").get(0).style.visibility = "hidden"
}
function HideEditLayer() {
	var editlayer = $("#statusEditPopup").get(0)
	editlayer.style.visibility = "hidden"
}
function HideInfoTooltip() {
	$("#empInfoTooltip").get(0).style.visibility = "hidden"
}
function EmpInfoHover(trigger) {
	var tooltipLayer = $("#empInfoTooltip").get(0)

	if (trigger.hovering) {
		trigger.hovering = null
		tooltipLayer.style.visibility = "hidden"
		return
	}
	trigger.hovering = 1

	//infoTriggerXX
	var eID = trigger.id.replace(/infoTrigger/, ""); assert(eID, "#134034")
	if (!top.empStatus[eID]) return //no data

	var hoverText
	var whenpunched = top.empStatus[eID].whenpunched //UTC date-string	e.g. 20 Jul 2008 22:41:14 GMT
	
	if (!whenpunched) { // no data = IMPLICIT OUT
		hoverText = "OUT (implicit)"

	}
	else { //got whenpunched
		//firebug("whenpunched: " + whenpunched)

		var localPunched = new Date(whenpunched) // [old:dateJS lib: Date.parse(whenpunched)]
		//firebug("localpunched: " + localPunched)
		if (!localPunched) logJSerr("localPunched null from whenpunched: " + whenpunched)

		var msDifference = (new Date()).getTime() - localPunched.getTime() // milliseconds diff between client-Now and time-of-punch
		//	firebug("msDiff: " + msDifference)

		// if client clock is behind, punch may be in "the future"; allow some leeway, otherwise only output status
		var dateAgo = ''
		if (msDifference < 0) {
			var minutesLeeway = -6
			if (msDifference >= minutesLeeway * 1000 * 60) {
				dateAgo = ElapsedDescription(0) //"just now"
			}
			else {
				// no when-description; alert server to client clock-weirdness
				$.ajax({
					url: 'ajaxserver.aspx?c=3&m=msDifference' + msDifference,
					timeout: 2000, //ms
					cache: false
				});
			}
		}
		else {
			dateAgo = ElapsedDescription(msDifference)
		}

		var status = new GetEmpStatus(eID) //default=OUT
		hoverText = status.description; 		if (dateAgo) hoverText += " (status set " + dateAgo + ")"
	
	}

	var offset = $(trigger).offset()

	tooltipLayer.innerHTML = hoverText
	tooltipLayer.style.top = offset.top - 22 //flex lineheight TODO
	tooltipLayer.style.left = offset.left + 10
	tooltipLayer.style.visibility = "visible"
}
function EmpInfoClick(trigger) {
	var eID = trigger.id.replace(/infoTrigger/, ""); assert(eID, "#494804")

	HideInfoTooltip() //"status set:..."

	var infoLayer = $("#empInfoPopup").get(0)
	var offset = $(trigger).offset()
	var jq = $(".statusRow[id=" + eID + "]"); assert(jq, "#506418")

	infoLayer.style.top = offset.top + jq.get(0).offsetHeight - 3 //row height
	infoLayer.style.left = offset.left + 20
	infoLayer.innerHTML = ""
	infoLayer.style.visibility = "visible"

	var htmlURI = "ajaxserver.aspx?c=2&eid=" + eID
	$("#empInfoPopup").load(htmlURI) //jQuery doesn't uniqueize GET URL with _############## string; provides accidental caching
}
function locTabClick(id) {
	//var id = $(jq).get(0).id

	CancelStatusEdit()
	HideEditLayer()
	$("#locTabs DIV").attr("class", "loc") //clear loc tabs
	SelectLocTab(id)
	SetTabInCookie()

/*	if (id == 1) { //Alaska?
		$("#orgTabs").css({ display: "block" })
	}
	else {
		$("#orgTabs").css({ display: "none" })
	} */
	RewriteTable()
}
function orgTabClick(id) {
	//var id = $(jq).get(0).id

	CancelStatusEdit()
	HideEditLayer()
	$("#orgTabs DIV").attr("class", "org") //clear
	SelectOrgTab(id)
	SetTabInCookie()
	RewriteTable()
}
function CancelStatusEdit() {
	if (empRowEditing) {
		var oPrior = $("#setTrigger" + empRowEditing).get(0)
		oPrior.value = "set" //restore
		HideEditLayer()
	}

	empRowEditing = ''
}
function SelectLocTab(loc) {
	$("#locTabs #" + loc).addClass("locSelected")
	currLocTab = loc
}
function SelectOrgTab(org) {
	$("#orgTabs #" + org).addClass("orgSelected")
	currOrgTab = org
}
function SetTabInCookie() {
	assert(currLocTab, "#50462")

	var cookieVal = currLocTab + ":" + currOrgTab
	$.cookie('esbTab', cookieVal, { expires: 200 }); //days
}
function CommentDefaultText() {
	return "Out for the day"
}
function ReturnDefaultText() {
	var today = new Date()
	var tomorrow = new Date(today.getTime() + 1 * 24 * 60 * 60 * 1000) //1 day

	var weekday = new Array(7);
	weekday[0] = "Sunday";
	weekday[1] = "Monday";
	weekday[2] = "Tuesday";
	weekday[3] = "Wednesday";
	weekday[4] = "Thursday";
	weekday[5] = "Friday";
	weekday[6] = "Saturday";

	var tomorrowstring = weekday[tomorrow.getDay()]
	if (tomorrowstring == "Saturday" || tomorrowstring == "Sunday")
		tomorrowstring = "Monday"
	
	return tomorrowstring
}
function SetCommentDefault() {
	$("#inputEditComments").get(0).value = CommentDefaultText()
}
function SetReturnDefault() {
	$("#inputEditReturn").get(0).value = ReturnDefaultText()
}
function GetUpdates() {
	assert(top.ttimestamp, "#607301")

	$.ajax({ url: 'ajaxserver.aspx?c=1&t=' + top.ttimestamp,
		timeout: 1000 * 20, //20 secs
		cache: false,
		error: function() { logJSerr('Error loading ajax document') },
		success: function(data, textStatus) {
			$('#lastUpdate').html("updated " + new Date().toLocaleTimeString())

			if (data && data.indexOf('_none') == -1) {
				firebug("evalling now")
				eval(data)
				RewriteTable()
			}
		}
	});

}

</script>
