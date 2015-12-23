<%@ Page Language="VB" %>

<script runat="server">

	Const validUsername As String = "EIOSB"
	Const validPassword As String = "EIOSB!"
	
	Protected Sub btnLogin_Click(ByVal sender As Object, ByVal e As System.EventArgs)

		If Me.username.Text = validUsername And Me.password.Text = validPassword Then
			
			' good login ; set dead-simple session cookie
			Admin.SetAuthentCookie()
			Response.Redirect("admin_empl.aspx", True)
		Else
			' bad login
			Me.message.Text = "Invalid login"
			
		End If
		
	End Sub
</script>

<html>
<head>
<title>Admin Login</title>
</head>
<body>

<h3>Please login</h3>

<div style="color:Red; font-size:13pt"><asp:Literal ID=message runat=server EnableViewState=false  /></div>

    <form id="form1" runat="server">

    <div>username</div>
    <asp:TextBox ID=username runat=server />
    
    <div><br /><br />password</div>
    <asp:TextBox ID=password runat=server TextMode=Password  />
     
	<asp:Button ID=btnLogin runat=server Text=Login OnClick="btnLogin_Click" />    
	
    </form>
</body>
</html>
