<%@ Application Language="VB" %>

<script RunAt="server">

	Protected Sub Application_BeginRequest(ByVal sender As Object, ByVal e As System.EventArgs)
		' session state not yet available 
		
	End Sub
	
	Protected Sub Application_PreRequestHandlerExecute(ByVal sender As Object, ByVal e As System.EventArgs)
		
		Exit Sub
		
		
		
		' PreRequestHandlerExecute fires even if: /WebResource.axd... handler		
		If Not (TypeOf Context.Handler Is IRequiresSessionState Or _
		   TypeOf Context.Handler Is IReadOnlySessionState) Then Exit Sub ' not normal .ASPX/etc. request
		
		If CBool(Session("UserCanBrowse")) Then Exit Sub ' OK

		If UserSession.IsValidExternalFormSubmission(Request) Then
			Session("UserCanBrowse") = True
			Exit Sub ' OK			
		End If
		
		If Business.UserLocation.IPIsKnownRIMOffice(Request.UserHostAddress) Then Exit Sub ' OK		
		
		If App.IsDevMachine Then Exit Sub ' OK
		
		' unknown / unauthenticated		
		Response.End() ' output nothing 		
	End Sub
	
	Sub Application_Start(ByVal sender As Object, ByVal e As EventArgs)
		App.Init()
        
	End Sub
    
	Sub Application_End(ByVal sender As Object, ByVal e As EventArgs)

	End Sub
        
	Sub Application_Error(ByVal sender As Object, ByVal e As EventArgs)
         
		Dim ex As Exception = Server.GetLastError()
		
		Dim errMsg As String = Nothing
		If Request IsNot Nothing AndAlso Request.Url IsNot Nothing Then _
		errMsg &= "[url:" & Request.Url.ToString() & "]" & Environment.NewLine
		
		errMsg &= DateTime.Now.ToString("MM dd yyyy hh:mm:ss tt: ") & ex.ToString() & Environment.NewLine

		App.MsgFile("TOPLEVEL-EXCEPTIONS.log", errMsg)
						
	End Sub

	Sub Session_Start(ByVal sender As Object, ByVal e As EventArgs)
		
		' log useragents, IPs etc.
		App.MsgFile("SessionStart_Request_" & Now.ToString("yyyy_MM_dd") & ".log", _
		  App.Timestamp & Request.UserHostName & vbTab & Request.UserHostAddress & vbTab & Request.Url.ToString() & vbTab & Request.UserAgent)
				
	End Sub
      	
	
	'Application_Start: 
	'As with traditional ASP, used to set up an application environment and only called when the application first starts.

	'Application_Init:
	'This method occurs after _start and is used for initializing code.

	'Application_Disposed: 
	'This method is invoked before destroying an instance of an application.

	'Application_Error: 
	'This event is used to handle all unhandled exceptions in the application.

	'Application_End: 
	'Again, like classic ASP, used to clean up variables and memory when an application ends.

	'Application_BeginRequest: 
	'This event is used when a client makes a request to any page in the application. It can be useful for redirecting or validating a page request.

	'Application_EndRequest:
	'After a request for a page has been made, this is the last event that is called.

	'Application_PreRequestHandlerExecute:
	'This event occurs just before ASP.Net begins executing a handler such as a page or a web service. At this point, the session state is available.

	'Application_PostRequestHandlerExecute: 
	'This event occurs when the ASP.Net handler finishes execution.

	'Application_PreSendRequestHeaders:
	'This event occurs just before ASP.Net sends HTTP Headers to the client. This can be useful if you want to modify a header

	'Application_PreSendRequestContent: 
	'This event occurs just before ASP.Net sends content to the client.

	'Application_AcquireRequestState: 
	'This event occurs when ASP.Net acquires the current state (eg. Session state) associated with the current request.

	'Application_ReleaseRequestState: 
	'This event occurs after ASP.NET finishes executing all request handlers and causes state modules to save the current state data.

	'Application_AuthenticateRequest:
	'This event occurs when the identity of the current user has been established as valid by the security module .

	'Application_AuthorizeRequest:
	'This event occurs when the user has been authorized to access the resources of the security module .

	'Session_Start: 
	'As with classic ASP, this event is triggered when any new user accesses the web site.

	'Session_End:
	'As with classic ASP, this event is triggered when a user's session times out or ends. Note this can be 20 mins (the default session timeout value) after the user actually leaves the site. 
	
</script>
