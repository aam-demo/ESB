<%@ Page Language="VB" %>

<script runat="server">
	
	Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs)
		
		App.ExceptionIfNotInitialized()
		Admin.EncounterAuthorizationGateway(Request)
		Response.Cache.SetCacheability(HttpCacheability.NoCache)
		Page.MaintainScrollPositionOnPostBack = True
		
	End Sub

	Private ReadOnly Property FriendlyLocationOrganization(ByVal locID As String, ByVal orgID As String) As String
		Get

			Dim loc As Byte = CByte(locID)
			Dim locDesc As String = (From l In DataMgr.AllLocations Where l.ID = loc Select l.Description).Single()
			
			If loc = Business.LOCATION.Alaska Then

				Dim org As Byte = CByte(orgID)
				Dim orgDesc As String = (From o In DataMgr.AllOrganizations Where o.ID = org Select o.Description).Single()
				
				Return locDesc & " : " & orgDesc
			Else
				' not Alaska - no org

				Return locDesc
			End If

		End Get
	End Property
	
	Protected Sub gvDeletedEmployees_RowDeleting(ByVal sender As Object, ByVal e As System.Web.UI.WebControls.GridViewDeleteEventArgs)
		
		e.Cancel = True
		
		Dim empIDStr As String = e.Keys(0).ToString ' first key field
		DataMgr.UNDELETE_Employee(empIDStr)	' refreshes Employees data
		 
		Me.gvDeletedEmployees.DataBind() ' rebind to refresh
		Me.outputMsg.Controls.Add(New LiteralControl("Employee UN-Deleted successfully."))
		
	End Sub
</script>

<html>
<head>
<title>Status Board: Admin: Undelete Employee</title>
<script src="../resources/jquery-1.2.6.pack.js" type="text/javascript"></script>
<link rel="stylesheet" type="text/css" href="admin.css">
<link rel="stylesheet" type="text/css" href="tabs.css">
</head>

<body>

<!--#include file="tabs.html"--> 

<%-- ***************************************--%>

<div>(Note: Photos of deleted employees are unavailable; recreate them if desired.)</div>

<asp:Panel ID=outputMsg runat=server EnableViewState=false />

    <form id="form1" runat="server">

	<asp:GridView ID=gvDeletedEmployees runat=server DataSourceID=lds_Deleted 
		DataKeyNames="employeeID"
			 CellPadding=3
		 AutoGenerateColumns=false AllowPaging=true PageSize=55 ShowHeader=true 
		 OnRowDeleting="gvDeletedEmployees_RowDeleting">
		 
		 <Columns>
			
			<asp:TemplateField ShowHeader=false>
				<ItemTemplate>
					<asp:Button ID=BtnUnDelete runat="server" 
						OnClientClick="return confirm('OK to UnDelete?');"
						CommandName="Delete" Text="UnDelete" />

				</ItemTemplate>
			</asp:TemplateField>
			
			<asp:BoundField datafield="id" ShowHeader=false Visible=false />
			
			<asp:boundfield datafield="fullname" headertext="fullname" SortExpression="fullname" /> 

			<asp:TemplateField ShowHeader=true HeaderText="office">
				<ItemTemplate>
					<%#FriendlyLocationOrganization(Eval("locationID"), Eval("organizationID"))%>
				</ItemTemplate>
			</asp:TemplateField>
			
			<asp:boundfield datafield="position_title" headertext="title" /> 

		 </Columns>
		 </asp:GridView>    

	<asp:LinqDataSource ID=lds_Deleted runat=server 
		ContextTypeName="ESBdb.EmployeeStatus" TableName="audit_EmployeeDeletion" 
		EnableDelete="false" EnableInsert="false" EnableUpdate="false" />
		
    </form>
</body>
</html>
