<%@ Page Title="Employee Status Board" Language="VB" MasterPageFile="~/main.master" %>

<script runat="server">

</script>

<asp:Content ID="Content1" ContentPlaceHolderID="head" Runat="Server">
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="PlaceHolder1" Runat="Server">

<table width=800><tr>
<td>

<div class="altsectionhead">
	Employee Status Board
</div>

<div style="padding:10px">

	<IFRAME width=720 height=1770 style="margin:0" frameborder=0 scrolling=auto 
		src="statusboard.aspx"></iframe>
</div>
</td></tr></table>

</asp:Content>
