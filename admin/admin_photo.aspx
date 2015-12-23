<%@ Page Language="VB" %>

<script runat="server">

	Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs)
		
		App.ExceptionIfNotInitialized()
		Admin.EncounterAuthorizationGateway(Request)
		Response.Cache.SetCacheability(HttpCacheability.NoCache)
		Page.MaintainScrollPositionOnPostBack = True
		Page.Form.Enctype = "multipart/form-data"	 ' for image upload (set every time)		
		
		Select Case Request.QueryString("c") ' command string			
			Case "u" : IsUploadView()
			Case "d" : HandleDelete()
		End Select
		
	End Sub

	Protected Sub Page_PreRender(ByVal sender As Object, ByVal e As System.EventArgs)

		If String.IsNullOrEmpty(Request.QueryString("c")) Then ' no command = default view
			IsBrowseView() ' [[ no longer relevant \\do here, post gridview-databinding]]
		End If
		
	End Sub
	
	Private Sub IsBrowseView()
		 
		Me.mv.SetActiveView(Me.v_browse)
		
		' set location filtering and display
		Dim usersLocID As Byte = Business.UserLocation.GetLocationIDFromPublicIP(App.CurrentRemoteIP)
		
		If Request.QueryString("locID") <> Nothing Then usersLocID = CByte(Request.QueryString("locID"))
		
		Dim locationDescrip As String = (From l In DataMgr.AllLocations Where l.ID = usersLocID Select l.Description).Single()
		Me.locationDisplay.Text = locationDescrip
		
		Me.ESBdbEmployees.Where = "locationID=" & usersLocID
		Me.lds_RimInc.Where = "locationID=" & Business.LOCATION.RIMInc
		
	End Sub
	
	Private Sub HandleDelete()
		Dim emplID = CShort(Request.QueryString("eID")) : Assert.True(Business.EmployeeID.IsValidEmpID(emplID))
		
		Using dc = DataMgr.NewDataContext
			dc.DELETE_EMPLOYEE_PHOTO(emplID)
		End Using
		
		EmpPhoto.RefreshPhotoInfo() ' get updated list
		EmpPhoto.HandleEmployeePhotoChange(emplID) ' remove from got-jpeg-file flag collection

		Response.Redirect("admin_photo.aspx", True)
		
	End Sub
	
	Private Sub IsUploadView()
		Me.mv.SetActiveView(Me.v_upload)
		
		Dim emplID = CShort(Request.QueryString("eID")) : Assert.True(Business.EmployeeID.IsValidEmpID(emplID))
		
		If Not Page.IsPostBack Then
			Me.plc_Instructions.Controls.Add(New LiteralControl( _
			    "Upload new photo for: " & DataMgr.AllEmployees.Where(Function(x) x.ID = emplID).Single().Fullname))
			'	 ^ New LiteralControl will not survive in Viewstate
			
			Exit Sub
		End If
		
		' is postback
			
		If Request.Files.Count = 0 OrElse Request.Files(0).ContentLength = 0 Then
			Me.responseMessage.Controls.Add(New LiteralControl("No file upload.")) : Exit Sub
		End If
			
		If Not UploadIsImage(Request.Files(0)) Then
			Me.responseMessage.Controls.Add(New LiteralControl("Not an image file.")) : Exit Sub
		End If

		Dim originalBytestream As Byte() = Tools.Stream2ByteArray(Request.Files(0).InputStream)

		' orig file not too big
		If originalBytestream.Length > EmpPhoto.bytesMaxOriginalFilesize Then Throw New ApplicationException("photo too big ")

		Dim md5Str = EmpPhoto.MD5SumOfBytestream(originalBytestream)
			
		' original file bytestream already in db?
		Using dc = DataMgr.NewDataContext
				
			Dim linqCount = (From phot In dc.PHOTOS _
			  Where phot.EmployeeID = emplID And phot.Md5_original_file = md5Str _
			 Select True).Count() '			 could also express as: dc.PHOTOS.Count (...
				
			If linqCount > 0 Then Response.Redirect("admin_photo.aspx", True) '  photo already exists in db					

			' get resized JPEG - verify webapp will later be able to serve a jpeg
				
			Dim resized = New ResizedJPEG(EmpPhoto.outputWidth, EmpPhoto.outputClipHeight, EmpPhoto.outputJPEGQuality, originalBytestream)
			Assert.True(resized.byteArray.Length > 0)	' must have an image
				
			' store in db (sproc will decide update vs. insert)
			dc.SET_EMPLOYEE_PHOTO(emplID, originalBytestream, md5Str)
			
		End Using
		
		EmpPhoto.HandleEmployeePhotoChange(emplID)

		Response.Redirect("admin_photo.aspx", True)
	End Sub
	
	ReadOnly Property CommandLinkForSetPhoto(ByVal emplID As String) As String
		Get
			Dim template As String = "<a href='admin_photo.aspx?c=u&eID={~ID~}'>{~verb~} photo</a>"
			
			Dim eID = CShort(emplID)
			Dim verb As String = If(EmpPhoto.EmployeePhotoJPEGIsAvailable(eID), "replace", "new")

			Dim res As String = Tools.Templatize(template, _
			 "ID", eID, _
			  "verb", verb)
			
			Return res
		End Get
	End Property
	
	ReadOnly Property CommandLinkForDELETE(ByVal emplID As String) As String
		Get
			
			Dim eID = CShort(emplID)
			If Not EmpPhoto.EmployeePhotoJPEGIsAvailable(eID) Then Return Nothing ' no photo in db
			
			Return "<a href=admin_photo.aspx?c=d&eID=" & emplID & _
			" onclick='return confirm(""Sure you want to delete?"")'>DELETE photo</a>"
			
		End Get
	End Property
	
	ReadOnly Property IMGTagForEmployee(ByVal emplID As String) As String
		Get
			
			Dim eID = CShort(emplID)
			If Not EmpPhoto.EmployeePhotoJPEGIsAvailable(eID) Then Return Nothing ' no photo in db
			
			Return String.Format("<IMG src={0} >", EmpPhoto.JPEGRelativeURI(eID, "../"))
			
		End Get
	End Property

	Private Function UploadIsImage(ByVal file1 As HttpPostedFile) As Boolean

		If Not IsNothing(file1) AndAlso (file1.ContentLength > 0) Then

			Dim ctType As String = file1.ContentType
			If ctType.StartsWith("image") And _
			 (ctType.IndexOf("gif") > 0 Or ctType.IndexOf("jpg") > 0 Or ctType.IndexOf("jpeg") > 0 Or ctType.IndexOf("png") > 0 Or ctType.IndexOf("bmp") > 0) _
			Then Return True

		End If
		
		Return False
	End Function
	
	Protected Sub gvBrowseEmployees_DataBound(ByVal sender As Object, ByVal e As System.EventArgs)

		Me.pageCount.Text = gvBrowseEmployees.PageCount
		Me.pageNum.Text = 1 + gvBrowseEmployees.PageIndex
		
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

<asp:Panel ID=responseMessage runat=server style="font-size:18pt; margin-bottom:10px" EnableViewState=false /> 
<asp:PlaceHolder ID=plc_Instructions runat=server EnableViewState=false />

<form id="form1" runat="server">

<asp:MultiView ID=mv runat=server >

<%-- ###########################################--%>
<asp:View ID=v_browse runat=server >

<h3><asp:Literal ID=locationDisplay runat=server/> Employees
(Page <asp:Literal ID=pageNum runat=server /> of
<asp:Literal ID=pageCount runat=server />)
</h3>

	<asp:GridView ID=gvBrowseEmployees runat=server 
		DataSourceID=ESBdbEmployees 	DataKeyNames="ID" 
		AllowPaging=true AllowSorting=true PageSize=30 CellPadding=3 AutoGenerateColumns=false OnDataBound="gvBrowseEmployees_DataBound">
		
		<Columns>
			<%--<asp:BoundField DataField=ID HeaderText=ID ReadOnly=true SortExpression=ID />
			<asp:BoundField DataField=locationID HeaderText=location ReadOnly=true SortExpression=locationID />--%>
			
			<asp:BoundField DataField=fullname HeaderText=Name ReadOnly=true SortExpression=fullname />
			
			<asp:TemplateField> 			
				<ItemTemplate>
					<table width=150><tr><td> <%#IMGTagForEmployee(Eval("ID"))%>  </td></tr></table>				 
				 </ItemTemplate> 				
			</asp:TemplateField>
			
			<asp:TemplateField> 			
				<ItemTemplate> <%#CommandLinkForSetPhoto(Eval("ID"))%></ItemTemplate> 	
			</asp:TemplateField>
			
			<asp:TemplateField> 			
				<ItemTemplate>  <%#CommandLinkForDELETE(Eval("ID"))%> </ItemTemplate> 
			</asp:TemplateField>
			
		</Columns>
		
		</asp:GridView>
	
	<asp:LinqDataSource ID="ESBdbEmployees" runat="server" 
		ContextTypeName="ESBdb.EmployeeStatus" TableName="EmployeesAdminView" 
		EnableDelete="false" EnableInsert="false" EnableUpdate="false" >
	</asp:LinqDataSource>

<%-- @@@@@@@@@@@@@@@@--%>

<h3>Rim Inc. Employees</h3> 

	<asp:GridView ID=gvRIMInc runat=server 
		DataSourceID=lds_RimInc  DataKeyNames="ID" 
		AllowPaging=true AllowSorting=true PageSize=30 CellPadding=3 AutoGenerateColumns=false >
		
		<Columns>
			<asp:BoundField DataField=fullname HeaderText=Name ReadOnly=true SortExpression=fullname />
			
			<asp:TemplateField> 			
				<ItemTemplate>
					<table width=150><tr><td> <%#IMGTagForEmployee(Eval("ID"))%>  </td></tr></table>				 
				 </ItemTemplate> 				
			</asp:TemplateField>
			
			<asp:TemplateField> 			
				<ItemTemplate> <%#CommandLinkForSetPhoto(Eval("ID"))%></ItemTemplate> 	
			</asp:TemplateField>
			
			<asp:TemplateField> 			
				<ItemTemplate>  <%#CommandLinkForDELETE(Eval("ID"))%> </ItemTemplate> 
			</asp:TemplateField>
			
		</Columns>
		
		</asp:GridView>
	
	<asp:LinqDataSource ID="lds_RimInc" runat="server" 
		ContextTypeName="ESBdb.EmployeeStatus" TableName="EmployeesAdminView" 
		EnableDelete="false" EnableInsert="false" EnableUpdate="false" >
	</asp:LinqDataSource>
	
</asp:View>

<%-- ###########################################--%>
<asp:View ID=v_upload runat=server >

<asp:FileUpload ID=file1 runat=server  />

<input type=button value="Upload" onclick="ClientBeginUpload(this)" />

<div id=uploadingFeedback style="visibility:hidden; margin:15px">
	<img src=images/bigrotation2.gif /> uploading...
</div>

</asp:View>

</asp:MultiView>
</form>
	
<script>
	function ClientBeginUpload(trigger) {
		trigger.disabled = true
		$("#uploadingFeedback").css("visibility", "visible")
		document.forms[0].submit()
	}
</script>
	
</body>
</html>
