Option Strict On : Option Explicit On : Option Infer On : Option Compare Binary

Imports System.Data.Linq, System.Linq
Imports ESBdb

''' <summary>
''' The Data Manager is a flexible Data Access Layer (DAL).  
''' It exposes (provides) a friendly LINQ DataContext which the app can use.
''' </summary>
''' 
Public Class DataMgr

	Private Shared _allEmployees As EMPLOYEES() ' for caching only (with all the good|bad that implies); expose via property 
	Public Shared ReadOnly AllOrganizations As ORGANIZATIONS()
	Public Shared ReadOnly AllLocations As LOCATIONS()
	' Public Shared ReadOnly AllPunchtypes As PUNCHTYPES()

	Public Shared ReadOnly IsInitted As Boolean = False

	''' <summary>
	''' initialize Class; implicitly calls Shared Sub New()
	''' </summary>
	'''
	Shared Sub Init()

	End Sub

	Shared Sub New() ' static constructor

		Using dc As New EmployeeStatus

			AllOrganizations = dc.ORGANIZATIONS.OrderBy(Function(x) x.ID).ToArray()	' get all
			AllLocations = dc.LOCATIONS.OrderBy(Function(x) x.ID).ToArray() ' get all
			' 	AllPunchtypes = dc.PUNCHTYPES.ToArray() ' get all
			_allEmployees = dc.EMPLOYEES.ToArray() ' get all ; must refresh on employee add/remove

			Assert.True(AllOrganizations.Count > 1)
			Assert.True(AllLocations.Count > 1)
			'  Assert.True(AllPunchtypes.Count > 1)
			Assert.True(_allEmployees.Count > 1)

			IsInitted = True ' all static members ready-to-go
		End Using

	End Sub

	Shared Sub DoDemoPunches()

		Static sr As New System.Random

		Using dc As ESBdb.EmployeeStatus = DataMgr.NewDataContext

			For Each nextEmp In DataMgr.ActiveEmployees

				If AscW(nextEmp.Fullname(0)) Mod 3 = 0 Then Continue For
				If sr.Next(3) > 0 Then Continue For

				Try

					' Dim utcHoursOffsetStr As String = "-7 Request.Form("utcHoursOffset")		' -7 for PDT, -9 for Anchorage (?), etc. etc.
					Dim utcHoursOffset As Short = -7 ' CInt(utcHoursOffsetStr) : Assert.True(utcHoursOffset >= -12 And utcHoursOffset <= 14) ' valid range = -12 to +14

					Dim utcNow As DateTime = Now.ToUniversalTime
					Dim ticksTimestamp As Long = utcNow.Ticks

					Dim emplID As Short = nextEmp.ID

					Dim punchtype As Byte = Business.PUNCHTYPE.IN
					If sr.Next(2) = 0 Then punchtype = Business.PUNCHTYPE.UNAVAIL

					dc.INSERT_EMPLOYEE_PUNCH(emplID, punchtype, utcNow, utcHoursOffset, ticksTimestamp, "demoIP", "", "")

				Catch ex As Exception
					App.Log(ex)

				End Try
			Next

		End Using

		DataMgr.ReloadEmployees()

	End Sub



	''' <summary>
	''' NOTE: includes everyone regardless of production status
	''' </summary>	
	'''
	Public Shared ReadOnly Property AllEmployees() As EMPLOYEES()
		Get
			Return _allEmployees
		End Get
	End Property

	''' <summary>
	''' only active employees (nonzero production status)
	''' </summary>
	'''
	Public Shared ReadOnly Property ActiveEmployees() As EMPLOYEES()
		Get
			Return _allEmployees.Where(Function(x) x.Production_status <> 0).ToArray
		End Get
	End Property

	''' <remarks>calling code is responsible for disposing (Using... recommended)</remarks>
	''' 	
	Shared ReadOnly Property NewDataContext() As ESBdb.EmployeeStatus
		Get
			Return New ESBdb.EmployeeStatus()
		End Get
	End Property

	''' <remarks> pulled from appSettings.config  (via Web.config)</remarks>
	'''
	Shared ReadOnly Property EmplStatusSQLServerConnString() As String
		Get
			Return "Data Source=.;Initial Catalog=EmployeeStatus;integrated security=true"


			' DEV conn string?
			If App.IsDevMachine Then Return ConfigurationManager.AppSettings("DEV_EmployeeStatusConnectionString")

			Return ConfigurationManager.AppSettings("EmployeeStatusConnectionString")
		End Get
	End Property

	Shared Sub InsertEmployee(ByVal fullname As String, ByVal validLocOrg As Business.LocationOrganization, ByVal phoneNumber As String, ByVal skypeUsername As String, ByVal email As String, ByVal positionTitle As String)

		Using dc As New EmployeeStatus
			'		dc.INSERT_EMPLOYEE(fullname, validLocOrg.locationID, validLocOrg.organizationID, phoneNumber, skypeUsername, email, positionTitle, App.CurrentRemoteIP)
			ReloadEmployees()

			Assert.True(_allEmployees.Count(Function(e) e.Fullname = fullname) = 1)	' must exist
		End Using

	End Sub

	Shared Sub DeleteEmployee(ByVal employeeID As String)

		Dim ID As Short = New Business.EmployeeID(employeeID).employeeID ' catastrophic if invalid; should never happen 

		Assert.True(_allEmployees.Count(Function(e) e.ID = ID) = 1)	' must exist to be deleted

		Using dc As New EmployeeStatus
			dc.DELETE_EMPLOYEE(ID, App.CurrentRemoteIP)
			ReloadEmployees()

			Assert.True(_allEmployees.Count(Function(e) e.ID = ID) = 0)	' must not exist
		End Using

	End Sub

	Shared Sub UNDELETE_Employee(ByVal employeeID As String)

		Dim ID As Short = New Business.EmployeeID(employeeID).employeeID ' catastrophic if invalid

		Using dc As New EmployeeStatus
			'		dc.Audit_UNDELETE_EMPLOYEE(ID, App.CurrentRemoteIP)
			ReloadEmployees()

		End Using

	End Sub

	Shared Sub ReloadEmployees()

		Using dc As New EmployeeStatus

			' refresh EMPLOYEES from db
			Dim tempAllEmployees As EMPLOYEES() = dc.EMPLOYEES.ToArray()
			_allEmployees = tempAllEmployees ' assumption: assignment statement implicitly threadblocking

		End Using
	End Sub

	' private helper method
	Private Shared ReadOnly Property EMPLOYEEDataMembers() _
	As System.Collections.ObjectModel.ReadOnlyCollection(Of System.Data.Linq.Mapping.MetaDataMember)
		Get
			Static members As System.Collections.ObjectModel.ReadOnlyCollection(Of System.Data.Linq.Mapping.MetaDataMember) = Nothing
			' do once and keep result
			If members Is Nothing Then
				members = NewDataContext().Mapping.MappingSource.GetModel( _
				 GetType(ESBdb.GeneratedDataContext)).GetMetaType( _
				 GetType(ESBdb.EMPLOYEES)).DataMembers()

			End If

			Return members
			' datacontext not Dispose'd; should be OK (?)

		End Get
	End Property

	Shared Function EMPLOYEEFieldWouldBeTruncated(ByVal toInsert As String, ByVal fieldname As String) As Boolean

		Assert.HasValue(toInsert) ' why not just return if null string?
		Assert.HasValue(fieldname)

		For Each m In EMPLOYEEDataMembers

			If Tools.StrEqual(m.Name, fieldname) Then
				Dim fieldSize As Integer = DBTextFieldSize(m)
				If fieldSize > 0 And toInsert.Length > fieldSize Then Return True Else Return False
			End If
		Next

		Throw New ApplicationException("EMPLOYEE fieldname not found OR size was unparseable (max?)")

	End Function

	' private helper method
	Private Shared Function DBTextFieldSize(ByVal metaDataMember As System.Data.Linq.Mapping.MetaDataMember) As Integer

		Dim fieldsize As Integer = 0
		Dim dbtype As String = metaDataMember.DbType

		' CASE SENSITIVE STRING COMPARES ***
		If dbtype.StartsWith("NChar") OrElse dbtype.StartsWith("NVarChar") _
		 OrElse dbtype.StartsWith("Char") OrElse dbtype.StartsWith("VarChar") Then

			Dim index1 = dbtype.IndexOf("(") : Dim index2 = dbtype.IndexOf(")")
			Dim len As String = dbtype.Substring(index1 + 1, index2 - index1 - 1)
			Integer.TryParse(len, fieldsize)
		End If

		Return fieldsize ' may be zero

	End Function

	Shared Function AllFieldnamesInEMPLOYEE() As String()

		Static result As String() = Nothing	' do once and keep result
		If result Is Nothing Then result = (From s In EMPLOYEEDataMembers Select s.Name).ToArray()

		Return result
	End Function

	Public Class MostRecentActivity

		Private Shared whenLastQueriedDatabase As DateTime? = Nothing
		Private Shared cachedData As ESBdb.MostRecentActivity() = Nothing

		Shared ReadOnly Property GetData(ByVal ticksTimestampStr As String, ByVal useCacheIfPossible As Boolean) _
		As ESBdb.MostRecentActivity()

			Get
				Static syncObj As Object : If syncObj Is Nothing Then syncObj = New Object

				SyncLock syncObj

					If Not useCacheIfPossible OrElse Not whenLastQueriedDatabase.HasValue OrElse _
					 (New TimeSpan(Now.Ticks - whenLastQueriedDatabase.Value.Ticks).TotalMinutes _
					  > AppSettings.minutesMostRecentActivityQueryCached) Then

						Using dc As EmployeeStatus = DataMgr.NewDataContext  '...could use dc's caching?

							Dim queryall = From d In dc.MostRecentActivity Select d ' get all rows
							cachedData = queryall.ToArray()
							whenLastQueriedDatabase = Now

							' App.Log("whenLastQueriedDatabase = Now; usecacheifpos=" & useCacheIfPossible)

						End Using
					End If
				End SyncLock

				' QUERY THE LOCAL ARRAY (timestamp str may be null)

				Dim q = From d In cachedData Where d.Punch_timestamp > ticksTimestampStr _
				   Select d

				Return q.ToArray() ' may have no items

			End Get
		End Property

	End Class

End Class

' add to the SQLMetal-generated stuff 

Namespace ESBdb

	''' <summary>
	''' friendly version of the generated EmployeeStatus DataContext
	''' </summary>
	'''
	Public Class EmployeeStatus
		Inherits ESBdb.GeneratedDataContext

		Private tw As System.IO.StringWriter

		' default (parameterless) constructor ; needed for bound ASP.NET controls
		Sub New()
			MyBase.New(DataMgr.EmplStatusSQLServerConnString)

			If AppSettings.DatacontextLogging Then tw = New System.IO.StringWriter : Me.Log = tw
		End Sub

		Sub New(ByVal logging As Boolean)
			MyBase.New(DataMgr.EmplStatusSQLServerConnString)

			If logging AndAlso tw Is Nothing Then tw = New System.IO.StringWriter : Me.Log = tw

		End Sub

		' for convenience, realize datacontext sql logging in Dispose()
		Protected Overrides Sub Dispose(ByVal disposing As Boolean)
			MyBase.Dispose(disposing)

			If tw IsNot Nothing Then
				App.MsgFile("dcSQL_" & Now.ToString("yyyy_MM_dd") & ".log", _
				  App.Timestamp & vbCrLf & tw.ToString)
				tw.Dispose()
			End If
		End Sub

	End Class

End Namespace
