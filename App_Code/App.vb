Option Strict On : Option Explicit On : Option Infer On : Option Compare Binary

Imports System.IO, System.Collections.Generic, System.Data.Linq, System.Linq
Imports Library
Imports ESBdb

Public Class DemoApp

	Public Shared Function DisplayFullname(ByVal fullname As String) As String

		Dim name As String = fullname.Substring(0, fullname.IndexOf(" ") + 2)
		Return name

	End Function

End Class

''' <summary>
''' webapp startup ; triggered in Global.asax
''' </summary>
'''
Public Class App

	Public Const versionDescription As String = "ESB v.2.0" ' should/could be AppSetting

	Public Shared ReadOnly isInitted As Boolean = False

	''' <summary>
	''' initialize webapp; implicitly calls Shared Sub New()
	''' </summary>
	'''
	Shared Sub Init()

	End Sub

	Shared Sub New() ' static constructor

		DataMgr.Init()
		If Not DataMgr.IsInitted Then Throw New ApplicationException("app cannot function without data manager")

		EmpPhoto.Init()
		Log("App initialized")
		isInitted = True



		' demo DEV **************************
		DataMgr.DoDemoPunches()

	End Sub

	Shared Sub ExceptionIfNotInitialized()
		If Not isInitted Then Throw New ApplicationException("*** App Not Initialized!!! ***")

	End Sub

	Shared ReadOnly Property ReadWritePath() As String
		' physical path to app's writeable dir (logfiles)
		' requirement: user NETWORK SERVICE has relevant folder privileges
		Get
			Return (System.Web.HttpRuntime.AppDomainAppPath & AppSettings.WebappReadWriteDirName)
		End Get
	End Property

	Shared ReadOnly Property StaticReadWritePath() As String
		' physical path to app's static writeable dir 
		' requirement: user NETWORK SERVICE has relevant folder privileges
		Get
			Return (System.Web.HttpRuntime.AppDomainAppPath & AppSettings.WebappStaticReadWriteDirName)
		End Get
	End Property

	Shared ReadOnly Property ASPXFilename(ByVal r As System.Web.HttpRequest) As String
		Get
			Dim parts As String() = r.FilePath.Split("/"c)
			Return parts(parts.Length - 1)
		End Get
	End Property

	Shared ReadOnly Property DateAndTimestamp() As String
		' for prefixing textfile output ; not pathsafe
		Get
			Return DateTime.Now.ToString("MM dd yyyy hh:mm:ss tt: ")
		End Get
	End Property

	Shared ReadOnly Property Timestamp() As String
		' for prefixing textfile output ; not pathsafe
		Get
			Return DateTime.Now.ToString("hh:mm:ss tt: ")
		End Get
	End Property

	''' <summary>
	''' append to the common log file
	''' </summary>
	'''
	Shared Sub Log(ByVal contents As String)

		Static syncObj As Object : If syncObj Is Nothing Then syncObj = New Object

		Try
			Dim filepath As String = ReadWritePath & "\!_APP_" & Now.ToString("yyyy_MM_dd") & ".LOG"
			Dim logline As String = String.Concat(Timestamp, contents, vbCrLf)

			SyncLock syncObj
				Tools.AppendFile(logline, filepath)
			End SyncLock

		Catch ex As Exception
			' TODO: log with windows event service, and/or send an email...

		End Try

	End Sub

	Shared Sub Log(ByVal exc As Exception)
		Log(exc.ToString())
	End Sub

	''' <summary>
	''' create/append to file in webapp's writeable folder (or subfolder)
	''' </summary>
	'''
	Shared Sub MsgFile(ByVal filename As String, ByVal contents As String)

		Static syncObj As Object : If syncObj Is Nothing Then syncObj = New Object

		SyncLock syncObj
			Tools.AppendFile(contents + vbCrLf, App.ReadWritePath + "\" + filename)
		End SyncLock

	End Sub

	''' <summary>
	''' get the named string chunk from templates.aspx
	''' </summary>
	'''
	Shared Function GetTemplate(ByVal templateName As String) As String

		Assert.HasValue(templateName.Trim)

		Using tw As New System.IO.StringWriter()
			HttpContext.Current.Server.Execute("~/templates.aspx?name=" & templateName, tw)

			Dim output As String = Tools.Trim(tw.ToString) ' TODO: clean up HTML page whitespace
			If String.IsNullOrEmpty(output) Then Log("templates.aspx: blank: name=" & templateName)

			Return output
		End Using

	End Function

	Shared ReadOnly Property CurrentRemoteIP() As String
		Get
			Dim uha As String = HttpContext.Current.Request.UserHostAddress
			' weird Vista/local IPv6 ??
			If uha.Contains(":") Then Return "127.0.0.1"

			Return uha

		End Get
	End Property

	Shared ReadOnly Property IsDevMachine() As Boolean
		Get
			Static DEV_Machinenames As String() = {"amcdaniel"}

			Return DEV_Machinenames.Contains(My.Computer.Name.ToLower)
		End Get
	End Property

	'	Shared ReadOnly Property HttpRequestIsInternal() As Boolean
	'		Get
	'			Return (CurrentRemoteIP = "127.0.0.1")
	'			' use request.islocal ? ; how handles Vista ipv6 :: weirdness

	'		End Get
	'	End Property

End Class

''' <summary>
''' get JS code-string to be eval()'d clientside
''' </summary>
'''
Public Class JSOutput

	''' <summary>
	''' get all employee data 
	''' </summary>
	'''
	Shared Function InitialEmployeeData() As String

		Dim out As New System.Text.StringBuilder

		' query local EMPLOYEES() array
		Dim empdata = From e In DataMgr.ActiveEmployees _
		 Select e.ID, e.Fullname, e.LocationID, e.OrganizationID, e.Phone_number

		For Each x In empdata

			Dim InitialEmployeeDataJSONTemplate As String = _
			App.GetTemplate("InitialEmployeeDataJSONTemplate")
			'			 empData[{~emplID~}]={name:{~name~}, phone:{~phone~},homeLoc:{~homeLoc~},homeOrg:{~homeOrg~}}

			Dim t As New Templatizer(InitialEmployeeDataJSONTemplate)

			t.AddContent("emplID", CStr(x.ID))

			' t.AddContent("name", Tools.JavaScriptSafe(Tools.HTMLEncodeExtra(x.Fullname)))
			t.AddContent("name", Tools.JavaScriptSafe(Tools.HTMLEncodeExtra(DemoApp.DisplayFullname(x.Fullname))))

			t.AddContent("phone", Tools.JavaScriptSafe(Tools.HTMLEncodeExtra(x.Phone_number)))
			t.AddContent("homeLoc", CStr(x.LocationID))
			t.AddContent("homeOrg", If(x.OrganizationID.HasValue, CStr(x.OrganizationID), Constant.singlequote & Constant.singlequote)) ' javascript nullstring if valueless

			out.Append(t.GetResult & vbCrLf)
		Next

		Return out.ToString()
	End Function

	''' <summary>
	''' latest status updates ; output includes latest ticks-timestamp string
	''' </summary>
	'''
	Shared Function StatusUpdate(ByVal ticksTimestampStr As String, ByVal useCacheIfPossible As Boolean) As String
		' TODO: validate timestamp str

		Dim newdata = DataMgr.MostRecentActivity.GetData(ticksTimestampStr, useCacheIfPossible)
		If newdata.Length = 0 Then Return Nothing ' no new data

		' send new data and updated timestamp string and last-modified time info
		Dim newTTimestamp As String = newdata.OrderByDescending(Function(x) x.Punch_timestamp).First().Punch_timestamp  ' max punch-ticks-timestamp

		Dim out As New System.Text.StringBuilder
		For Each x In newdata

			Dim StatusUpdateJSONTemplate As String = App.GetTemplate("StatusUpdateJSONTemplate")
			' empStatus[{~emplID~}]={punch:{~punchtype~}, comment:{~comment~}, returntext:{~returntext~} } whenpunched:''

			Dim t As New Templatizer(StatusUpdateJSONTemplate)

			t.AddContent("emplID", CStr(x.EmployeeID))

			Dim useManualPunch As Boolean = True ' default (normal), output user's action
			' AUTO-SET "OUT" STATUS ??? ; if In/Unavail, display as Out because of passage of time?

			'If x.Trigger_auto_out And ( _
			' x.Punchtype = Business.PUNCHTYPE.IN Or x.Punchtype = Business.PUNCHTYPE.UNAVAIL) Then

			'	t.AddContent("punchtype", CStr(Business.PUNCHTYPE.OUT))	' employee is OUT but no punch-out time is given
			'	t.AddContent("comment", Constant.singlequote & Constant.singlequote)
			'	t.AddContent("returntext", Constant.singlequote & Constant.singlequote)
			'	t.AddContent("whenpunched", Constant.singlequote & Constant.singlequote)

			'	useManualPunch = False ' use artificial, display-only punch
			'End If

			If useManualPunch Then

				' get UTC-time to send to client
				' assumption: webserver and db-server in same timezone 
				'	Dim gmtString As String = x.When_punched_utc.Value.ToString("R")	' culture invariant format-specifier (for GMT) ==> Fri, 04 Jan 2008 15:44:30 GMT
				Dim gmtString As String = x.When_punched.Value.ToString("R") ' culture invariant format-specifier (for GMT) ==> Fri, 04 Jan 2008 15:44:30 GMT
				gmtString = gmtString.Substring(5)	' strip abbrev weekday ' TODO: maybe strip seconds suffix, :00

				t.AddContent("punchtype", CStr(x.Punchtype)) ' is Byte? but will always have value
				t.AddContent("comment", Tools.JavaScriptSafe(Tools.HTMLEncodeExtra(x.Comment_text)))
				t.AddContent("returntext", Tools.JavaScriptSafe(Tools.HTMLEncodeExtra(x.Return_text)))
				t.AddContent("whenpunched", Tools.JavaScriptSafe(gmtString))
			End If

			out.Append(t.GetResult & vbCrLf)
		Next

		' response-string to be eval()'d
		Dim result As String = String.Concat( _
		 "top.ttimestamp=", Constant.singlequote, newTTimestamp, Constant.singlequote, vbCrLf, _
		 out.ToString(), vbCrLf)

		' (force "top" window clientside so the scope/container is explicit)

		Return result
	End Function

End Class

''' <summary>
''' employee photo constants and static functions
''' </summary>
'''
Public Class EmpPhoto

	' embedded constants:
	Public Const outputWidth As Integer = 150, outputClipHeight As Integer = 300
	Public Const outputJPEGQuality As Long = 95L
	Public Const bytesMaxOriginalFilesize As Integer = 1024 * 1024 * 3 ' x megs

	Private Shared ReadOnly empIDsKnownGoodJPEGFiles As New Dictionary(Of Short, Boolean)	 ' for this app-lifetime 
	Private Shared ReadOnly origPhotoMD5ForEmployee As New Dictionary(Of Short, String)

	Shared Sub Init()

	End Sub

	Shared Sub New() ' static constructor

		RefreshPhotoInfo()
		'	CleanOldJPEGFiles() ' <-- relies on origPhotoMD5ForEmployee

	End Sub

	Shared Sub RefreshPhotoInfo()

		SyncLock origPhotoMD5ForEmployee

			origPhotoMD5ForEmployee.Clear()

			Using dc = DataMgr.NewDataContext
				Dim q = (From photinfo In dc.PHOTOS Select photinfo.EmployeeID, photinfo.Md5_original_file)

				For Each row In q
					origPhotoMD5ForEmployee.Item(row.EmployeeID) = row.Md5_original_file
				Next
			End Using

		End SyncLock

	End Sub

	''' <summary>
	''' run once at appdomain startup
	''' </summary>
	'''
	Shared Sub CleanOldJPEGFiles()

		Dim allFiles = System.IO.Directory.GetFiles(GeneratedPhotosRoot)
		Dim validFiles = New List(Of String)

		For Each item In origPhotoMD5ForEmployee.AsEnumerable()

			Dim path As String = GeneratedJPEGPathFor(item.Key, item.Value)
			validFiles.Add(path)
		Next

		Dim oldFiles = allFiles.Except(validFiles).ToArray
		Dim numKilled As Integer = 0

		For Each killfile In oldFiles
			Try
				System.IO.File.Delete(killfile)
				numKilled += 1

			Catch ex As Exception
				App.Log(ex)

			End Try
		Next

		If numKilled > 0 Then
			App.Log("CleanOldJPEGFiles: deleted " & numKilled)
		End If

	End Sub

	Shared Function MD5SumOfBytestream(ByVal ba As Byte()) As String

		Dim md5Original As Byte() = New System.Security.Cryptography.MD5CryptoServiceProvider().ComputeHash(ba)
		Return Tools.ByteArrayToHexString(md5Original)
	End Function

	Shared Function JPEGRelativeURI(ByVal employeeID As Short, _
	  Optional ByVal relativePrefix As String = Nothing) As String

		Dim md5str As String = ReadOrigPhotoMD5ForEmployee(employeeID)

		Return String.Concat( _
		relativePrefix, AppSettings.WebappStaticReadWriteDirName, "/_generated_employeephotos/", JPEGFilename(employeeID, md5str))

		' generated_ folder name  *** SYNCHRONIZE MANUALLY

	End Function

	Private Shared Function GeneratedJPEGPathFor(ByVal employeeID As Short, ByVal md5sum As String) As String

		Return String.Concat(GeneratedPhotosRoot, JPEGFilename(employeeID, md5sum))
	End Function

	Private Shared Function JPEGFilename(ByVal employeeID As Short, ByVal md5sum As String) As String

		Return String.Concat(CStr(employeeID), "_", md5sum, "_", outputWidth, ".jpg")
	End Function

	'Shared Function SourcePhotoDirNameFor(ByVal empl As ESBdb.EMPLOYEES) As String

	'	Return String.Concat( _
	'	SourcePhotosRoot, SquishedEmployeeName(empl.Fullname), "[", empl.ID, "]") ' e.g. Francis[555]

	'End Function

	Private Shared Function SquishedEmployeeName(ByVal s As String) As String
		Return Regex.Replace(s, "\s|[.]", "")
	End Function

	'Shared ReadOnly Property SourcePhotosRoot() As String
	'	Get
	'		Return App.StaticReadWritePath & "\employeephotos\originals\"
	'	End Get
	'End Property

	Private Shared ReadOnly Property GeneratedPhotosRoot() As String
		Get
			Return App.StaticReadWritePath & "\_generated_employeephotos\"
		End Get
	End Property

	Private Shared Function ReadOrigPhotoMD5ForEmployee(ByVal employeeID As Short) As String

		Dim md5Str As String = Nothing
		SyncLock origPhotoMD5ForEmployee ' wait to read
			origPhotoMD5ForEmployee.TryGetValue(employeeID, md5Str)

		End SyncLock

		Return md5Str
	End Function

	''' <summary>
	''' creates JPEG and writes to disk if employee has photo
	''' </summary>
	'''
	Shared Function EmployeePhotoJPEGIsAvailable(ByVal employeeID As Short) As Boolean

		SyncLock empIDsKnownGoodJPEGFiles

			If empIDsKnownGoodJPEGFiles.ContainsKey(employeeID) Then

				Return empIDsKnownGoodJPEGFiles.Item(employeeID) ' only True vals
			End If

			Assert.True(Directory.Exists(EmpPhoto.GeneratedPhotosRoot))	' destination for all jpeg files

			Dim md5Str As String = ReadOrigPhotoMD5ForEmployee(employeeID)
			If String.IsNullOrEmpty(md5Str) Then Return False ' no emp photo 

			' jpeg file generated ?
			Dim jpegFilepath As String = EmpPhoto.GeneratedJPEGPathFor(employeeID, md5Str)

			If File.Exists(jpegFilepath) Then
				'  App.Log("File.Exists(existingFilepath" & jpegFilepath)
				empIDsKnownGoodJPEGFiles.Item(employeeID) = True
				Return True	' already exists

			End If

			' generate & write jpeg file

			' get bytestream from db
			Dim bytestream As Byte()
			Using dc = DataMgr.NewDataContext
				bytestream = (From phot In dc.PHOTOS Where phot.EmployeeID = employeeID Select phot.Original_file).Single().ToArray

			End Using

			' get resized JPEG
			Dim resized = New ResizedJPEG(EmpPhoto.outputWidth, EmpPhoto.outputClipHeight, EmpPhoto.outputJPEGQuality, bytestream)
			Assert.True(resized.byteArray.Length > 0)	' must have an image

			' write to local disk

			Try
				File.WriteAllBytes(jpegFilepath, resized.byteArray)
				App.Log("wrote new gen'd emp photo: " & jpegFilepath)

			Catch ex As Exception
				App.Log(ex)
				Return False

			End Try
			'TODO: confirm all bytes written to file

			empIDsKnownGoodJPEGFiles.Item(employeeID) = True
		End SyncLock

		Return True

	End Function

	''' <summary>
	''' new bytestream and md5sum in db, but jpeg files created lazily
	''' </summary>
	'''
	Shared Sub HandleEmployeePhotoChange(ByVal employeeID As Short)

		SyncLock empIDsKnownGoodJPEGFiles ' necessary? 

			' will need to generate jpeg when next requested ; do not just set FALSE, we assume only TRUE values
			empIDsKnownGoodJPEGFiles.Remove(employeeID) ' Remove() silent if not found
		End SyncLock

		RefreshPhotoInfo()
	End Sub

End Class

''' <summary>
''' constant values pulled from appSettings.config 
''' </summary>
'''
Public Class AppSettings

	Shared ReadOnly Property DatacontextLogging() As Boolean
		Get
			' blank=NO ; any value=YES
			Return Not String.IsNullOrEmpty(ConfigurationManager.AppSettings("DataContextSQLLogging"))
		End Get
	End Property

	Shared ReadOnly Property WebappReadWriteDirName() As String
		Get
			Return ConfigurationManager.AppSettings("webappReadWriteDir")
		End Get
	End Property

	Shared ReadOnly Property WebappStaticReadWriteDirName() As String
		Get
			Return ConfigurationManager.AppSettings("webappStaticReadWriteDir")
		End Get
	End Property

	Shared ReadOnly Property minutesMostRecentActivityQueryCached() As Integer
		Get
			Return CInt(ConfigurationManager.AppSettings("minutesMostRecentActivityQueryCached")) 'TODO: confirm within valid range
		End Get
	End Property

	Shared ReadOnly Property minutesBrowserAJAXUpdateInterval() As Integer
		Get
			Return CInt(ConfigurationManager.AppSettings("minutesBrowserAJAXUpdateInterval")) 'TODO: confirm within valid range
		End Get
	End Property

End Class

''' <summary>
''' stuff shared by various admin pages
''' </summary>
'''
Public Class Admin

	Private Const cookieName As String = "eiosbCkee", cookieVal As String = "set"
	Private Const redirToPage As String = "login.aspx"

	''' <summary>
	''' redir to login.aspx if not authenticated
	''' </summary>
	'''
	Shared Sub EncounterAuthorizationGateway(ByVal r As System.Web.HttpRequest)

		If Not ExistsAuthentCookie(r) AndAlso Not App.IsDevMachine _
		 Then HttpContext.Current.Response.Redirect(redirToPage, True)

	End Sub

	Shared Sub SetAuthentCookie()

		HttpContext.Current.Response.Cookies.Add(New HttpCookie(cookieName, cookieVal))
	End Sub

	Private Shared Function ExistsAuthentCookie(ByVal r As System.Web.HttpRequest) As Boolean

		If r.Cookies(cookieName) IsNot Nothing AndAlso r.Cookies.Get(cookieName).Value = cookieVal Then Return True
		Return False

	End Function
End Class

Public Class UserSession

	Shared ReadOnly Property IsValidExternalFormSubmission(ByVal req As HttpRequest) As Boolean
		Get
			Return (req.Form("{0f63d47e-9aaf-4bc7-b621-e4e09ddcf30a}") = "{fcfc79b7-6254-4e6c-8ec5-b870f2b93101}")
		End Get
	End Property

End Class
