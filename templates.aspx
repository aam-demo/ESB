<%@ Page Language="VB" EnableSessionState="false" EnableViewState="false" Trace="false" %>

<script runat="server">
	
	' This aspx is not directly served; the webapp uses it by calling Server.Execute().
	' Querystring param 'name' specifies the desired template to output.

	' TEMPLATE NOTES  [to come]
	
	Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs)
		
		Try
			Dim templateName As String = Request.QueryString("name")
			Dim c As Control = Me.FindControl(templateName)
			CType(c, Literal).Visible = True
			
		Catch ex As Exception
			' add URL to exception?
			App.Log(ex)
			
		End Try
		 
	End Sub
</script>

<%-- NOTE: javascript in tag-attribute-handlers (onclick=...) should be parseable (for IE6); 
		so alert({Name}) is BAD, alert('{Name}') is good --%>

<%-- REMEMBER TO MANUALLY CORRELATE: 
		column widths in StatusTable vs. StatusTableEmployeeRow--%>

<asp:literal id="StatusTable" runat="server" visible=False>

<table class="statusHead" width=100%>
<tr>
<td width=40%>Employee</td>
<td width=15%><%-- blank SET column--%></td>
<!--<td width=30%>Comments</td>-->
<td width=15%>Return</td>
</tr>
</table>

</asp:literal>

<%-- *****************************************************************--%>

<asp:literal id="StatusTableEmployeeRow" runat="server" visible=False>

<table class="statusRow" id="{~ID~}" width=100%>
<tr class="{~indicatorClass~}">

<td width=40%>
	<table cellpadding=0 cellspacing=0 width=262 border=0>
	<tr>
		<td><img src=resources/images/icon_user.gif width=16 height=16 
					id=infoTrigger{~ID~}
					onclick="EmpInfoClick(this)"
					onmouseover="EmpInfoHover(this)" 
					onmouseout="EmpInfoHover(this)">
		</td>
		<td width=56%>{~EmployeeName~}</td>
		<td width=44% align="left" style="font: normal 8pt tahoma,arial">{~PhoneNumber~}</td>
	</tr></table>	
</td>

<td align="center" width=15%>
	<input type=button id=setTrigger{~ID~} 
		style="font-weight:normal; margin:0;padding:0"
		onclick="HandleStatusEdit('{~ID~}'); return false" value="{~btnVALUE~}">
</td>

<!--<td width=30%>{~comments~}</td>-->

<td width=15%>{~returntext~}</td>
</tr>
</table> 
</asp:literal>

<%-- *****************************************************************--%>

<asp:literal id=setStatusEditLayerTemplate runat=server visible=false>

<span id=editname></span>
<hr noshade>

<div>{~btn1~}</div> 

<table width=99%><tr valign=middle >
	<td>
	
	<div>Comments 
		<A class=textfieldDefaultSetter href="javascript:void(SetCommentDefault())" title="{~commentsTitle~}">+</A></div>
		<input type=text style="width:130px" id=inputEditComments>		

	<div style="margin-top:12px">Return
		<A class=textfieldDefaultSetter href="javascript:void(SetReturnDefault())" title="{~returnTitle~}">+</A></div>
		<input type=text style="width:130px" id=inputEditReturn>		
	</td>

	<td>
	<div style="height:30px;">{~btn2~}</div> 
	<div style="margin-top:8px">{~btn3~}</div> 
	</td>

</tr></table>

</asp:literal>

<%-- *****************************************************************--%>
<asp:literal id=InitialEmployeeDataJSONTemplate runat=server visible=false>

empData['{~emplID~}']={name:{~name~}, phone:{~phone~},homeLoc:{~homeLoc~},homeOrg:{~homeOrg~}}

</asp:literal>
<%-- *****************************************************************--%>

<asp:literal id=StatusUpdateJSONTemplate runat=server visible=false>

top.empStatus['{~emplID~}']={punch:{~punchtype~}, whenpunched:{~whenpunched~}, comment:{~comment~}, returntext:{~returntext~} }

</asp:literal>

<%-- *****************************************************************--%>

<asp:literal id="emplInfoPopupTemplate" runat="server" visible=False>

<table width=385><tr>
<td>
	<a href="javascript:void(HideEmpInfoPopup())"><img align=top src="resources/images/icon_closewindow.gif" /></a>
</td>
<td width=100% align=center >
	<span style="font-size:16pt; font-style:italic "> {~Name~} </span> 
</td>
</tr></table>

<table class="infoPopup" width=210 align=left style="margin-top:9px">
<tr>	<td width=30%>Phone</td>	<td width=65%><b>{~phone~}</b></td>	</tr>
<tr>	<td>Email</td>		<td>{~email~}</td>		</tr>
<tr>	<td>Skype</td>	<td><b>{~Skype~}</b></td>		</tr>
<tr>	<td>Title</td>		<td><b>{~title~}</b></td>		</tr>
</table>

{~emplphotoIMGtag~}

</asp:literal> 

<%-- *****************************************************************--%>

<asp:literal id="emplInfoIMGTagTemplate" runat="server" visible=False>

<IMG src="{~IMGsrc~}" align=left>

</asp:literal> 

