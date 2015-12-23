<%@ Page Language="VB" %>

<script runat="server">
	' the ASPNET lifecycle: child init (always) | page init | page load | child load (always) | validators | servervalidate | events | parent prerender | child prerender (IF VISIBLE)
	' NOTE: GridView output will htmlencode [<"&] ; watch out for ' in JS-strings ; databinding [<]%#Eval() strangely leaves '>' untouched
	
	Private responseMsg As String

	Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs)
		
		App.ExceptionIfNotInitialized()
		' Admin.EncounterAuthorizationGateway(Request)
		If Not Request.IsLocal Then Response.End()
		
		Response.Cache.SetCacheability(HttpCacheability.NoCache)
		Page.MaintainScrollPositionOnPostBack = True
		SetLocationFilteringAndDisplay()
		
	End Sub
	
	Private Sub SetLocationFilteringAndDisplay()
		 
		Dim usersLocID As Byte = Business.UserLocation.GetLocationIDFromPublicIP(App.CurrentRemoteIP)
		
		If Request.QueryString("locID") <> Nothing Then usersLocID = CByte(Request.QueryString("locID"))
		
		Dim locationDescrip As String = (From l In DataMgr.AllLocations Where l.ID = usersLocID Select l.Description).Single()
		Me.locationDisplay.Text = locationDescrip
		
		Me.ESBdbEmployees.Where = "locationID=" & usersLocID
		Me.LinqDataSource_RimInc.Where = "locationID=" & Business.LOCATION.RIMInc
		
	End Sub
	
	Private Sub DeleteEmployee(ByVal empID As String)
		
		DataMgr.DeleteEmployee(empID)

		responseMsg = "Deleted employee ID: " & empID
	End Sub
	
	Private Sub UpdateEmployee(ByVal e As System.Web.UI.WebControls.GridViewUpdateEventArgs)
		
		Dim empID As String = e.Keys(0)
		Dim ID As Short = New Business.EmployeeID(empID).employeeID	' catastrophic if invalid; should never happen
		' \\\old [ locID included in gridview's datakeys to make readonly (uneditable) ]
		
		Dim anyChange As Boolean = False ' flag
		
		Using dc = DataMgr.NewDataContext()		' technically, should start a Transaction 
			
			' get Employee-being-updated
			Dim current = (From currempl In dc.EMPLOYEES Select currempl Where currempl.ID = ID).Single()
			Dim auditEntry As New ESBdb.Audit_EMPLOYEE_CHANGES ' capture being-overwritten values

			'		 \old\\\\\\\		 [July08] [dbo].[AUDIT_EMPLOYEE_UPDATE] '-- the webapp must supply ONLY THE OLD VALUES (which will be overwritten)

			' iterate, look for changed values
			For Each k In e.NewValues.Keys

				If Tools.StrEqual(e.NewValues(k), e.OldValues(k)) Then Continue For ' no change
				anyChange = True

				Select Case k.ToString.ToLower

					Case "fullname"
						auditEntry.Fullname = e.OldValues(k)
						current.Fullname = e.NewValues(k)

					Case "phone_number"
						auditEntry.Phone_number = e.OldValues(k)
						current.Phone_number = e.NewValues(k)

					Case "skype_username"
						auditEntry.Skype_username = e.OldValues(k)
						current.Skype_username = e.NewValues(k)

					Case "email"
						auditEntry.Email = e.OldValues(k)
						current.Email = e.NewValues(k)

					Case "position_title"
						auditEntry.Position_title = e.OldValues(k)
						current.Position_title = e.NewValues(k)

				End Select
			Next

			If Not anyChange Then Exit Sub ' no updates

			' save NEW values in physical EMPLOYEES ; allow possible auto silent truncation of string fields (fullname , phone_number ...)
			Dim success As Boolean = False
			
			Try
				dc.SubmitChanges()
				success = True
				
			Catch ex As System.Data.Linq.ChangeConflictException
				' merge user vals (prioritized) and new db vals ' dc.GetChangeSet() ==> objectdumper
				' MSDN: The 'keep changes' option keeps all changes from the current user and merges changes from other users if the corresponding field was not changed by the current user.
				dc.ChangeConflicts.ResolveAll(Data.Linq.RefreshMode.KeepChanges)
				success = True

			Catch ex As Exception
				App.Log(ex)
				responseMsg = "Update failed. Please try again."

			Finally
				DataMgr.ReloadEmployees() ' whether successful or not, reload app's EMPLOYEES array
				Me.gvEmployees.DataBind() ' update GridView (rebind to data-control which pulls from db)

			End Try

			' save old values for auditing
			If success Then

				auditEntry.EmployeeID = current.ID
				auditEntry.Change_remoteIP = App.CurrentRemoteIP
				auditEntry.Changemaker_type = 1 ' admin (default)
				auditEntry.Change_type = 2 ' --change_type UPDATE
				auditEntry.Change_when = DateTime.Now
				
				' LINQSQL: INSERT INTO [audit].[EMPLOYEE_CHANGES]([changemaker_type], [change_type], [change_when], [change_remoteIP], [employeeID], [fullname], [production_status], [phone_number], [Skype_username], [email], [position_title]) VALUES (@p0, @p1, @p2, @p3, @p4, @p5, @p6, @p7, @p8, @p9, @p10)
				
				dc.Audit_EMPLOYEE_CHANGES.InsertOnSubmit(auditEntry)	' maybe... should just stick with sprocs
				dc.SubmitChanges()
					
			End If
		End Using

	End Sub
	
	Protected Sub gvEmployees_RowDeleting(ByVal sender As Object, ByVal e As System.Web.UI.WebControls.GridViewDeleteEventArgs) _
	 Handles gvEmployees.RowDeleting
 
		DeleteEmployee(e.Keys(0))
		Me.gvEmployees.DataBind() ' show change		
		gvEmployees.EditIndex = -1 ' stop editing (DELETE link always clickable)
		e.Cancel = True ' cancel; LinqDataSource shouldn't do anything		
	End Sub
 
	Protected Sub gvEmployees_RowUpdating(ByVal sender As Object, ByVal e As System.Web.UI.WebControls.GridViewUpdateEventArgs) _
	 Handles gvEmployees.RowUpdating
		
		UpdateEmployee(e)
		gvEmployees.EditIndex = -1 ' stop editing
		e.Cancel = True ' cancel; LinqDataSource shouldn't do anything
	End Sub

	Protected Sub Page_PreRender(ByVal sender As Object, ByVal e As System.EventArgs)

		' encode user-input-strings; do once here
		If Not String.IsNullOrEmpty(responseMsg) Then
			ActionResponseMessage.Text = Tools.HTMLEncodeExtra(responseMsg)
			ActionResponse.Visible = True
		End If
	End Sub
	
	' ----------------------------------------------------------------------------------------------------------------------

	Protected Sub gvRimInc_RowDeleting(ByVal sender As Object, ByVal e As System.Web.UI.WebControls.GridViewDeleteEventArgs)

		DeleteEmployee(e.Keys(0))
		Me.gvRimInc.DataBind() ' show change
		gvEmployees.EditIndex = -1 ' stop editing (DELETE link always clickable)
		e.Cancel = True ' cancel; LinqDataSource shouldn't do anything		
	End Sub

	Protected Sub gvRimInc_RowUpdating(ByVal sender As Object, ByVal e As System.Web.UI.WebControls.GridViewUpdateEventArgs)

		UpdateEmployee(e)
		gvRimInc.EditIndex = -1	' stop editing
		e.Cancel = True ' cancel; LinqDataSource shouldn't do anything
	End Sub

	Protected Sub gvEmployees_DataBound(ByVal sender As Object, ByVal e As System.EventArgs)

		Me.pageCount.Text = gvEmployees.PageCount
		Me.pageNum.Text = 1 + gvEmployees.PageIndex
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

<%-- @@@@@@@@@@@@--%>

<h3><asp:Literal ID=locationDisplay runat=server/> Employees
(Page <asp:Literal ID=pageNum runat=server /> of
<asp:Literal ID=pageCount runat=server />)
</h3>
	
	<asp:GridView ID="gvEmployees" runat="server" 
		DataSourceID="ESBdbEmployees" DataKeyNames="ID"
		 AutoGenerateColumns=false AutoGenerateDeleteButton="false" AutoGenerateEditButton="true" 
		AllowPaging="true" AllowSorting="true"
		ShowHeader="true" PageSize="28" CellPadding=2 
		OnDataBound="gvEmployees_DataBound">
		
		<HeaderStyle Font-Size="8pt" />
		<Columns> 
		
			<asp:BoundField datafield="id" ShowHeader=false Visible=false />
			
			<asp:boundfield datafield="fullname" headertext="fullname" SortExpression="fullname" /> 
			
			<asp:checkboxfield datafield="has_photo" headertext="photo" ReadOnly=true SortExpression="has_photo" /> 

			<asp:boundfield datafield="phone_number" headertext="phone" /> 
			 
			<asp:boundfield datafield="skype_username" headertext="skype" /> 
			
			<asp:boundfield datafield="email" headertext="email" /> 
			
			<asp:boundfield datafield="position_title" headertext="title" /> 
			
			<asp:TemplateField ShowHeader=false>
				<ItemTemplate>
					<asp:Button ID=BtnDelete runat="server" 
						CssClass=<%# Eval("fullname") %> OnClientClick="return confirm('OK to Delete ' + this.className + '?');"
						CommandName="Delete" Text="Delete" />
				</ItemTemplate>
			</asp:TemplateField>

		</Columns>
	</asp:GridView>
	
	<asp:LinqDataSource ID="ESBdbEmployees" runat="server" 
		ContextTypeName="ESBdb.EmployeeStatus" TableName="EmployeesAdminView" 
		EnableDelete="false" EnableInsert="false" EnableUpdate="false" >
	</asp:LinqDataSource>

<%-- @@@@@@@@@@@@--%>

<h4>Rim Inc. Employees</h4>
	
	<asp:GridView ID="gvRimInc" runat="server" 
		DataSourceID="LinqDataSource_RimInc" DataKeyNames="ID"
		 AutoGenerateColumns=false AutoGenerateDeleteButton="false" AutoGenerateEditButton="true" 
		AllowPaging="true" AllowSorting="true"
		ShowHeader="true" PageSize="20" CellPadding=2 OnRowDeleting="gvRimInc_RowDeleting" OnRowUpdating="gvRimInc_RowUpdating">
		
		<HeaderStyle Font-Size="8pt" />
		<Columns> 
		
			<asp:BoundField datafield="id" ShowHeader=false Visible=false />
			
			<asp:boundfield datafield="fullname" headertext="fullname" /> 
			
			<asp:checkboxfield datafield="has_photo" headertext="photo" ReadOnly=true /> 

			<asp:boundfield datafield="phone_number" headertext="phone" /> 
			 
			<asp:boundfield datafield="skype_username" headertext="skype" /> 
			
			<asp:boundfield datafield="email" headertext="email" /> 
			
			<asp:boundfield datafield="position_title" headertext="title" /> 
			
			<asp:TemplateField ShowHeader=false>
				<ItemTemplate>
					<asp:Button ID=BtnDelete runat="server" 
						CssClass=<%# Eval("fullname") %> OnClientClick="return confirm('OK to Delete ' + this.className + '?');"
						CommandName="Delete" Text="Delete" />
				</ItemTemplate>
			</asp:TemplateField>

		</Columns>
	</asp:GridView>
	
	<asp:LinqDataSource ID="LinqDataSource_RimInc" runat="server" 
		ContextTypeName="ESBdb.EmployeeStatus" TableName="EmployeesAdminView" 
		EnableDelete="false" EnableInsert="false" EnableUpdate="false" >
	</asp:LinqDataSource>
	
<%-- ##############--%>
	
</form>
	
</body>
</html>
