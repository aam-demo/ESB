Option Strict On : Option Explicit On : Option Infer On : Option Compare Binary
Imports Business

' business rules and requirements

Namespace Business

	Public Enum PUNCHTYPE As Byte			' must manually correlate values with db ***
		OUT = 1 : [IN] = 2 : UNAVAIL = 3
	End Enum

	Public Enum LOCATION As Byte				' must manually correlate values with db ***
		Alaska = 1 : Guam = 2 : Hawaii = 3 : California = 4 : RIMInc = 5
	End Enum

	Public Class EmpStatus

		Shared ReadOnly Property PunchDescriptionFor(ByVal punch_type As Byte) As String
			Get
				Select Case punch_type
					Case PUNCHTYPE.OUT : Return "Out"
					Case PUNCHTYPE.IN : Return "In"
					Case PUNCHTYPE.UNAVAIL : Return "Unavailable"

					Case Else
						Throw New ApplicationException("invalid punch_type")
				End Select

			End Get
		End Property
	End Class

	''' <summary>
	'''  must be valid; exception if not
	''' </summary>
	'''
	Public Class EmployeeID

		Public ReadOnly employeeID As Short

		Sub New(ByVal suspectEmployeeID As String)

			Dim emplID As Short = 0
			Dim parsed As Boolean = Short.TryParse(suspectEmployeeID, emplID)
			Assert.True(parsed)
			Assert.IsPositive(emplID) ' > 0

			Me.employeeID = emplID
		End Sub

		Shared ReadOnly Property IsValidEmpID(ByVal suspectEmpID As Short) As Boolean
			Get
				Return (1 = DataMgr.AllEmployees.Count(Function(x) x.ID = suspectEmpID))
			End Get
		End Property
	End Class

	Public Class UserLocation

		Shared ReadOnly AlaskaOffsets As Integer() = {-8, -9}
		Shared ReadOnly CalifOffsets As Integer() = {-7, -8}
		Shared ReadOnly HawaiiOffsets As Integer() = {-10}	 ' Daylight Saving Time is not observed in Hawaii, which maintains its 10 hours difference behind GMT
		Shared ReadOnly GuamOffsets As Integer() = {10}	' Guam is located in the GMT+10 time zone, and there is no daylight savings time.

		Shared Function GetLocationIDFromPublicIP(ByVal publicIP As String) As LOCATION

			Select Case publicIP

				Case "202.128.20.159" ' 					Session("UserOffice") = "GU"
					Return LOCATION.Guam

				Case "66.175.65.46"  ' 					Session("UserOffice") = "HI"
					Return LOCATION.Hawaii

				Case "69.109.82.97"  ' 					Session("UserOffice") = "CA"
					Return LOCATION.California

				Case "209.165.140.194"	' 					Session("UserOffice") = "AK"
					Return LOCATION.Alaska

				Case Else
					Return LOCATION.RIMInc		' default (unknown) ; may mask bad code

			End Select

		End Function

		Shared Function IPIsKnownRIMOffice(ByVal remoteIP As String) As Boolean

			Return (GetLocationIDFromPublicIP(remoteIP) <> LOCATION.RIMInc)

			' RIM Inc has no location, is known only by login
		End Function

		Shared Function GetLocationIDFromTimezone(ByVal timezone As Integer) As Byte

			If AlaskaOffsets.Contains(timezone) Then Return LOCATION.Alaska
			If CalifOffsets.Contains(timezone) Then Return LOCATION.California
			If HawaiiOffsets.Contains(timezone) Then Return LOCATION.Hawaii
			If GuamOffsets.Contains(timezone) Then Return LOCATION.Guam

			' default (unknown) ; may mask bad code
			Return LOCATION.RIMInc

		End Function

		Shared Function CanAcceptPunchFromTimezone(ByVal employeeToPunch As Short, ByVal questionableTimezone As Integer) As Boolean

			Dim locID = DataMgr.ActiveEmployees.Where(Function(x) x.ID = employeeToPunch).Single().LocationID
			Assert.True(locID > 0)

			Select Case CType(locID, LOCATION)

				Case LOCATION.RIMInc : Return True ' RIM Inc. basically locationless

				Case LOCATION.Alaska : Return AlaskaOffsets.Contains(questionableTimezone)
				Case LOCATION.California : Return CalifOffsets.Contains(questionableTimezone)
				Case LOCATION.Hawaii : Return HawaiiOffsets.Contains(questionableTimezone)
				Case LOCATION.Guam : Return GuamOffsets.Contains(questionableTimezone)

				Case Else
					App.Log("bad timezone in CanAcceptPunchFromTimezone")
					Return False

			End Select

		End Function

	End Class

	Public Class LocationOrganization

		Public ReadOnly locationID, organizationID As Byte?
		Public ReadOnly IsValid As Boolean = False
		Public ReadOnly whyInvalid As String ' information msg

		' TODO: make Enums for all

		Sub New(ByVal suspectLocationID As String, ByVal suspectOrganizationID As String)

			Dim locID As Byte : Byte.TryParse(suspectLocationID, locID)
			If locID <= 0 Then whyInvalid = "Invalid location ID" : Exit Sub
			'							 ("If locID <= 0"... Byte is unsigned)
			If Not IsValidLocID(locID) Then whyInvalid = "Undefined location ID" : Exit Sub

			' validate org ID
			Dim orgID As Byte? = Nothing ' optional

			If Not String.IsNullOrEmpty(suspectOrganizationID) Then

				Dim orgresult As Byte : Byte.TryParse(suspectOrganizationID, orgresult)
				If orgresult <= 0 Then whyInvalid = "Invalid organization ID" : Exit Sub
				If Not IsValidOrgID(orgresult) Then whyInvalid = "Undefined organization ID" : Exit Sub

				If locID <> 1 Then whyInvalid = "Only Alaska location has organization ID" : Exit Sub

				orgID = orgresult
			End If

			' LocID:1 Alaska requires orgID		'					TODO: Enums for locID, orgID 
			If locID = 1 AndAlso Not orgID.HasValue Then whyInvalid = "Alaska location requires organization ID" : Exit Sub

			Me.locationID = locID
			Me.organizationID = orgID ' may, validly, be Nothing

			Me.IsValid = True
		End Sub

		Shared ReadOnly Property IsValidLocID(ByVal suspectLocID As Byte) As Boolean
			Get
				Return (1 = DataMgr.AllLocations.Count(Function(x) x.ID = suspectLocID))
			End Get
		End Property

		Shared ReadOnly Property IsValidOrgID(ByVal suspectOrgID As Byte) As Boolean
			Get
				Return (1 = DataMgr.AllOrganizations.Count(Function(x) x.ID = suspectOrgID))
			End Get
		End Property

	End Class

End Namespace
