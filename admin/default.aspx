<%@ Page Language="VB" %>

<script runat="server">
	
	Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs)
		
		App.ExceptionIfNotInitialized()
		
		Response.Redirect("admin_empl.aspx", True) ' now main page		
	End Sub

</script>

<html>
<head>

</head>
<body>

<%--<h2>ESB Admin</h2>
<br />

<asp:Panel ID=responseMessage runat=server style="font-size:18pt; margin-bottom:10px" EnableViewState=false /> 

<form id="form1" runat="server">

<a href="admin_empl.aspx" style="font-size:14pt">Edit / Insert Employees</a>
<br /><br />
<a href="admin_report.aspx" style="font-size:14pt">View Employee Status History</a>
<br /><br />
<a href="admin_photo.aspx" style="font-size:14pt">Handle Employee Photos</a>

<br /><br /><br /><br />

</form>
	--%>
</body>
</html>
