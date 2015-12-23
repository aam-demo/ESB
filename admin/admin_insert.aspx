<%@ Page Language="VB"  %>

<script runat="server">
	' the ASPNET lifecycle: child init (always) | page init | page load | child load (always) | validators | servervalidate | events | parent prerender | child prerender (IF VISIBLE)
	
	Private responseMsg As String

	Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs)

		App.ExceptionIfNotInitialized()
		' Admin.EncounterAuthorizationGateway(Request)
		If Not Request.IsLocal Then Response.End()
		
		
		If Not IsPostBack Then ' don't rebind
			Me.drop_LocationOrg.DataSource = LocOrgDropdownData
			Me.drop_LocationOrg.DataValueField = "1"
			Me.drop_LocationOrg.DataTextField = "2"
			
			Me.drop_LocationOrg.DataBind()
		End If

	End Sub

	' INSERT EMPLOYEE
	
	Private Sub InsertEmployee()

		Dim fullname As String = Tools.SuperTrim(Me.Fullname.Text)
		
		Dim partsLocOrg As String() = Me.drop_LocationOrg.SelectedValue.Split(":")
		Dim locationID As String = partsLocOrg(0)
		Dim organizationID As String = partsLocOrg(1) ' may be zero
		If organizationID = "0" Then organizationID = Nothing
		
		Dim phoneNumber As String = Tools.SuperTrim(Me.Phone_number.Text)
		Dim skypeUsername As String = Tools.SuperTrim(Me.Skype_username.Text)
		Dim email As String = Tools.SuperTrim(Me.Email.Text)
		Dim positionTitle As String = Tools.SuperTrim(Me.Position_title.Text)

		' fullname and location  always required 

		If String.IsNullOrEmpty(fullname) Then responseMsg = "Fullname is required" : Exit Sub

		If DataMgr.EMPLOYEEFieldWouldBeTruncated(fullname, "fullname") Then _
		responseMsg = "Fullname too long" : Exit Sub

		If Not String.IsNullOrEmpty(phoneNumber) AndAlso _
		  DataMgr.EMPLOYEEFieldWouldBeTruncated(phoneNumber, "phone_number") Then _
		 responseMsg = "Phone number too long" : Exit Sub
		
		If Not String.IsNullOrEmpty(skypeUsername) AndAlso _
		  DataMgr.EMPLOYEEFieldWouldBeTruncated(skypeUsername, "skype_username") Then _
		 responseMsg = "Skype too long" : Exit Sub
		
		If Not String.IsNullOrEmpty(email) AndAlso _
		  DataMgr.EMPLOYEEFieldWouldBeTruncated(email, "email") Then _
		 responseMsg = "Email too long" : Exit Sub
		
		If Not String.IsNullOrEmpty(positionTitle) AndAlso _
		  DataMgr.EMPLOYEEFieldWouldBeTruncated(positionTitle, "position_title") Then _
		 responseMsg = "Title too long" : Exit Sub
		
		Dim validLocOrg = New Business.LocationOrganization(locationID, organizationID)
		If Not validLocOrg.IsValid Then responseMsg = validLocOrg.whyInvalid : Exit Sub ' should never happen

		' proceed with insert
		DataMgr.InsertEmployee(fullname, validLocOrg, phoneNumber, skypeUsername, email, positionTitle)
		responseMsg = "Inserted new employee: " & fullname

	End Sub

	Protected Sub Page_PreRender(ByVal sender As Object, ByVal e As System.EventArgs)

		' encode possible user-input-strings; do once here
		If Not String.IsNullOrEmpty(responseMsg) Then
			ActionResponseMessage.Text = Tools.HTMLEncodeExtra(responseMsg)
			ActionResponse.Visible = True
		End If

	End Sub

	Private ReadOnly Property LocOrgDropdownData() As System.Data.DataTable
		Get
			Dim dt As New System.Data.DataTable()
			dt.Columns.Add("1")
			dt.Columns.Add("2")

			Dim q = (From l In DataMgr.AllLocations Where l.ID = Business.LOCATION.Alaska Select l).Single()
			Dim idPrefix As String = q.ID.ToString()
			Dim descripPrefix As String = q.Description
			
			Dim q2 = (From o In DataMgr.AllOrganizations Select o)
			For Each org In q2
				
				dt.Rows.Add(New Object() {idPrefix & ":" & org.ID, descripPrefix & " : " & org.Description})
			Next
			
			Dim q3 = (From l In DataMgr.AllLocations Where l.ID <> Business.LOCATION.Alaska Select l)
			For Each locat In q3
				
				dt.Rows.Add(New Object() {locat.ID & ":0", locat.Description})
			Next
			
			Return dt
		End Get
	End Property
	' ----------------------------------------------------------------------------------------------------------------------

	Protected Sub btnInsert_Click(ByVal sender As Object, ByVal e As System.EventArgs)
		
		InsertEmployee()
	End Sub
</script>

<html>
<head>
<title>Admin: RIM Employee Status Board</title>
<script src="../resources/jquery-1.2.6.pack.js" type="text/javascript"></script>
<link rel="stylesheet" type="text/css" href="admin.css">
<link rel="stylesheet" type="text/css" href="tabs.css">
</head>

<body>

<!--#include file="tabs.html"--> 

<%-- ***************************************--%>

<form id="form1" runat="server">
	
	<asp:Panel ID=ActionResponse runat=server Visible=false 
		style="background-color:cyan; font-size:16pt">
		<asp:Literal ID=ActionResponseMessage runat=server EnableViewState=false />	
	</asp:Panel>
	
	<h3>Insert employee</h3>

<table cellspacing=2 cellpadding=3 rules="all" border="1" >
	<tr>
		<td>
			Fullname<span style="color:red">*</span>
		</td>
		<td>
			 <asp:textbox runat=server id="Fullname" />
		</td>
	</tr>
	<tr>
		<td>
			Location<span style="color:red">*</span>
		</td>
		<td>
			 <asp:DropDownList ID=drop_LocationOrg runat=server />
		</td>
	</tr>
	
	<tr>
		<td>
			Phone
		</td>
		<td>
			 <asp:textbox runat=server id="Phone_number" />
		</td>
	</tr>
	<tr>
		<td>
			Skype
		</td>
		<td>
			 <asp:textbox runat=server id="Skype_username" />
		</td>
	</tr>
	<tr>
		<td>
			Email
		</td>
		<td>
			 <asp:textbox runat=server id="Email" />
		</td>
	</tr>
	<tr>
		<td>
			Title
		</td>
		<td>
			 <asp:textbox runat=server id="Position_title" />
		</td>
	</tr>
</table>

	<div style="margin-left:190px; font-size:9pt"><span style="color:red">*</span> = required</div>

	<div style="margin:15"> <asp:Button ID=btnInsert runat=server Text=Insert OnClick="btnInsert_Click" /> </div> 
	
</form>
	
</body>
</html>
