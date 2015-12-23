<%@ Page Language="VB" Trace="false" EnableViewState="false" %>

<script runat="server">
	Const outputDivider As String = vbTab & "|" & vbTab
	
	Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs)
		
		Response.Cache.SetCacheability(HttpCacheability.NoCache)
		
		' log (debugging)
		App.MsgFile("AJAX-request_" & Now.ToString("yyyy_MM_dd") & ".log", _
		  App.Timestamp & Request.UserHostAddress & outputDivider & Request.Url.ToString())
		
		Dim commandStr As String = Request.QueryString("c")  ' ajaxserver.aspx?c=[__]
		Select Case commandStr

			Case "1" : DataMgr.DoDemoPunches() : HandleStatusUpdate() ' HANDLE REQUEST FOR LATEST STATUS

			Case "2" : ServeEmployeePopupLayer()
			Case "3" : HandleClientClockBehind()
			Case "x" : LogClientsideError()

			Case Else
				App.Log("invalid ajaxserver command: " & Request.Url.ToString)
				NoResponse()
				
		End Select
	End Sub
	
	Private Sub HandleStatusUpdate()
		 
		Dim tickstimestampStr As String = Request.QueryString("t") ' may be blank
		' TODO: validate timestamp str
		
		Dim resp As String = JSOutput.StatusUpdate(tickstimestampStr, True) ' use cached data (if available)
		
		If String.IsNullOrEmpty(resp) Then
			' no new data
			'		App.Log("ajaxs - no new data (url was:" & Request.Url.ToString)
			NoResponse()
		End If

		App.Log("ajax sending: " & resp)
		Response.Write(resp)
		
	End Sub
	
	' command "3"
	
	Private Sub HandleClientClockBehind()
		
		Dim msg As String = Request.QueryString("m")
		App.MsgFile("client-clock-slow.LOG", msg)
		
	End Sub
	
	' command "2" : ajaxserver.aspx?c=2&eid=' + employee ID
	
	Private Sub ServeEmployeePopupLayer()
		
		Dim emplIDStr As String = Request.QueryString("eid")
		Dim emplID As Short
		
		If Not Short.TryParse(emplIDStr, emplID) Then
			App.Log("ServeEmployeePopupLayer: bad eid: " & emplIDStr)
			NoResponse() ' Response.End
		End If
		
		Dim emplData = DataMgr.AllEmployees.Single(Function(x) x.ID = emplID) ' error if not found, global.asax will catch&log
		'			Dim gotPhoto As Boolean = EmpPhoto.EmployeePhotoJPEGIsAvailable(emplID)	' creates jpeg file if needed/possible
	
		' (sending an entire HTML chunk instead of only the relevant data-bits, i.e., templating serverside [bad] [lazy])
		
		Dim t As New Templatizer(App.GetTemplate("emplInfoPopupTemplate")) ' info popup layer
		'			 {~Name~} {~phone~}  email  Skype   title  {~emplphotoIMGtag~}

		t.AddContent("Name", Tools.HTMLEncodeExtra(DemoApp.DisplayFullname(emplData.Fullname)))
		t.AddContent("phone", Tools.HTMLEncodeExtra(emplData.Phone_number))
		
		Dim emailStr = Tools.HTMLEncodeExtra(emplData.Email)
		emailStr = If(Not String.IsNullOrEmpty(emailStr), _
		 String.Format("<a id=emplInfoEmailLink href=mailto:{0}>{0}</a>", emailStr), _
		 Nothing)
		
		t.AddContent("email", emailStr)
		'TODO: validate & sanitize email str on input 
		
		t.AddContent("Skype", Tools.HTMLEncodeExtra(emplData.Skype_username))
		t.AddContent("title", Tools.HTMLEncodeExtra(emplData.Position_title))
		
		Dim IMGtag As String = Nothing
		Static sr As New System.Random
		Dim empPhotNum = sr.Next(1, 4) ' 1-3
		Dim imgSrc = String.Format("emp{0}.jpg", empPhotNum)
		
		Dim emplInfoIMGTagTemplate As String = App.GetTemplate("emplInfoIMGTagTemplate")
		IMGtag = Tools.Templatize(emplInfoIMGTagTemplate, _
		  "IMGsrc", imgSrc)
		
		
		'If gotPhoto Then
		'	Dim emplInfoIMGTagTemplate As String = App.GetTemplate("emplInfoIMGTagTemplate")
		'	IMGtag = Tools.Templatize(emplInfoIMGTagTemplate, _
		'	  "IMGsrc", EmpPhoto.JPEGRelativeURI(emplID))

		'End If
		
		t.AddContent("emplphotoIMGtag", IMGtag)
		Response.Write(t.GetResult)
		
	End Sub
	
	Private Sub LogClientsideError()
		
		Dim errorMsgFromClient As String = Request.QueryString("m")
		
		' write even if msg blank
		App.MsgFile("client-JSerr.log", _
		  App.DateAndTimestamp & outputDivider & Request.UserHostAddress & outputDivider & errorMsgFromClient)
		
		NoResponse()
	End Sub
	
	Private Sub NoResponse()
		
		Response.Write("<_none/>") ' empty element for client's xmlhttprequest 
		Response.End()
	End Sub
	
</script>
