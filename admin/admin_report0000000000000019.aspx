<%@ Page Language="VB"  %>

<script runat="server">
	' the ASPNET lifecycle: child init (always) | page init | page load | child load (always) | validators | servervalidate | events | parent prerender | child prerender (IF VISIBLE)
	
	Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs)
		
		App.ExceptionIfNotInitialized()
		'Admin.EncounterAuthorizationGateway(Request)
		
		If Not Page.IsPostBack Then ' bind only once, then rely on viewstate
			
			Dim q = From emp In DataMgr.AllEmployees Select emp.ID, emp.Fullname
		
			ddlSelectEmp.DataSource = q
			ddlSelectEmp.DataTextField = "fullname"
			ddlSelectEmp.DataValueField = "ID"
			ddlSelectEmp.DataBind()
		
			Me.Calendar1.SelectionMode = CalendarSelectionMode.DayWeekMonth
 			
		Else
			' postback
						
		End If
		
	End Sub
	
	Protected Sub ddlSelectEmp_SelectedIndexChanged(ByVal sender As Object, ByVal e As System.EventArgs) _
	     Handles ddlSelectEmp.SelectedIndexChanged
		
		'							SetDaterangeValidForEmployee()[too presumptious]

		' INIT		
		Me.Calendar1.VisibleDate = Date.Today : Me.Calendar2.VisibleDate = Date.Today	' asp.net Calendar chokes if any time-info
		Me.Calendar1.SelectedDate = Nothing
		Me.Calendar2.SelectedDate = Nothing
		
	End Sub
	
	' GENERATE REPORT 
	
	Protected Sub btnGenerateReport_Click(ByVal sender As Object, ByVal e As System.EventArgs)

		If Me.Calendar1.SelectedDates.Count = 0 Then
			SetActionResponseMsg("No daterange selected")
			Exit Sub
			
		End If
		
		Dim emplID As Short = CShort(Me.ddlSelectEmp.SelectedValue)
		Assert.True(Business.EmployeeID.IsValidEmpID(emplID))
				
		' get all dates with punches		
		Using dc = DataMgr.NewDataContext
			
			' VIEW EmployeeInOutHistory  reflects only In/Out changes
			
			Dim allDates = (From activity In dc.EmployeeInOutHistory Where activity.EmployeeID = emplID _
		    Select activity.When_punched Distinct).Cast(Of Date).ToArray()
			
			If allDates.Length = 0 Then
				Me.reportOutput.Text = "No employee activity."
				Exit Sub
				
			End If
			
			Dim rangeStart As Date, rangeEnd As Date
			rangeStart = Me.Calendar1.SelectedDates(0)
			rangeEnd = Me.Calendar1.SelectedDates(Me.Calendar1.SelectedDates.Count - 1) ' may be same as rangestart
			
			' meaningful range-end selected in Cal2 ?
			If Me.Calendar2.SelectedDate > rangeEnd Then rangeEnd = Me.Calendar2.SelectedDate
			
			Assert.True(rangeStart > Date.MinValue And rangeEnd > Date.MinValue And rangeEnd >= rangeStart)
			
			Dim sb As New System.Text.StringBuilder ' accumulate report rows
			Dim dateIterator As Date = rangeEnd
			
			Do While dateIterator >= rangeStart	'  backwards in time
				
				' got data?
				If allDates.Count(Function(x) Tools.DateEqualsTimeless(x, dateIterator)) = 0 Then
					App.Log("Not allDates.Contains(dateIterator")
					GoTo nextIteration
					
				End If
				
				Dim statusChanges = (From changes In dc.EmployeeInOutHistory _
				 Where changes.EmployeeID = emplID And changes.When_punched.HasValue AndAlso _
				 (changes.When_punched.Value.Date = dateIterator) _
				   Order By changes.When_punched Descending _
				   Select changes).ToArray
				
				' LINQSQL: AND (DATEADD(HOUR, -DATEPART(HOUR, [t0].[when_punched]), DATEADD(MINUTE, -DATEPART(MINUTE, [t0].[when_punched]), DATEADD(SECOND, -DATEPART(SECOND, [t0].[when_punched]), DATEADD(MILLISECOND, -DATEPART(MILLISECOND, [t0].[when_punched]), [t0].[when_punched])))) = @p1)
				' NOTE: changes.When_punched is time-localized in the db view
				
				Dim alreadyOutputHeader As Boolean = False
				
				For Each sc In statusChanges
					
					Dim t As New Templatizer(Me.reportRowTemplate.Text) '{~rowdate~} >{~statusChange~} {~timeOfChange~} {~comments~}
					
					Dim dateheaderStr = Nothing
					If Not alreadyOutputHeader Then
						sb.Append("<div style='border-bottom:1px solid red'>&nbsp;</div>") ' EMBEDDED HTML nasty nasty
						dateheaderStr = dateIterator.ToLongDateString
						alreadyOutputHeader = True

					End If
						
					t.AddContent("rowdate", dateheaderStr)
					
					t.AddContent("statusChange", Business.EmpStatus.PunchDescriptionFor(sc.Punchtype))
					t.AddContent("timeOfChange", sc.When_punched.Value.ToShortTimeString)
					
					Dim commentsStr As String = Tools.HTMLEncodeExtra(sc.Comment_text) ' may be nullstring
					' any return text?
					If Not String.IsNullOrEmpty(sc.Return_text) Then _
					commentsStr &= String.Concat( _
					     Constant.onespace, "<i>[", Tools.HTMLEncodeExtra(sc.Return_text), "]</i>") ' embedded html					
					t.AddContent("comments", commentsStr)
					
					sb.Append(t.GetResult)
				Next
				
nextIteration:
				dateIterator = dateIterator.AddDays(-1)
			Loop
			
			' anything to output?
			If sb.Length > 0 Then
		
				Dim employeeFullname As String
				employeeFullname = (From emp In DataMgr.AllEmployees Where emp.ID = emplID Select emp.Fullname).Single()
				
				Dim complete As String = String.Concat( _
				"<div style='background-color:cyan; font-weight:bold'>", _
				Tools.HTMLEncodeExtra(employeeFullname), _
				"</div>", sb.ToString())				'							 NASTY EMBEDDED HTML
				
				Me.reportOutput.Text = complete
			Else
				
				Me.reportOutput.Text = "No activity within selected daterange."
			End If
			
		End Using
		
	End Sub
	'-----------------------------------------------------------------------------------------------------------------
	Private Sub SetActionResponseMsg(ByVal msg As String)
	
		Me.ActionResponseMessage.Text = msg
		Me.ActionResponse.Visible = True
		
	End Sub
	
</script>

<html>
<head>
<title>Admin: RIM Employee Status Board</title>
<link rel="stylesheet" type="text/css" href="admin.css">
<%--<link rel="stylesheet" type="text/css" href="tabs.css">--%>
</head>
<body>

	<form id="form1" runat="server">
	
<h2> <a href="default.aspx">ESB Admin</a>: Status History Report </h2>
<div> Record of In | Out punches </div>

	<asp:Panel ID=ActionResponse runat=server 
		style="background-color:cyan; font-size:16pt">
		<asp:Literal ID=ActionResponseMessage runat=server EnableViewState=false />	
	</asp:Panel>
<br />

<table cellspacing=15 cellpadding=3>
<tr valign=top>
<td>

	<h3>Select Employee </h3>

	<asp:DropDownList ID=ddlSelectEmp runat=server 
		AutoPostBack=true  />

</td>

<td>

		<h4> Choose day, week, or month </h4>
		
	<asp:Calendar ID="Calendar1" runat="server" BackColor="White" 
		BorderColor="#999999" CellPadding="4" DayNameFormat="Shortest" 
		Font-Names="Verdana" Font-Size="8pt" ForeColor="Black" Height="180px" 
		Width="220px">
		<SelectedDayStyle BackColor="#666666" Font-Bold="True" ForeColor="White" />
		<SelectorStyle BackColor="#CCCCCC" />
		<WeekendDayStyle BackColor="#FFFFCC" />
		<TodayDayStyle BackColor="#CCCCCC" ForeColor="Black" />
		<OtherMonthDayStyle ForeColor="#808080" />
		<NextPrevStyle VerticalAlign="Bottom" />
		<DayHeaderStyle BackColor="#CCCCCC" Font-Bold="True" Font-Size="7pt" />
		<TitleStyle BackColor="#999999" BorderColor="Black" Font-Bold="True" />
	</asp:Calendar>

</td>

<td>
		<h4> [optional] choose end day</h4> 
		
	<asp:Calendar ID="Calendar2" runat="server" BackColor="White" 
		BorderColor="#999999" CellPadding="4" DayNameFormat="Shortest" 
		Font-Names="Verdana" Font-Size="8pt" ForeColor="Black" Height="180px" 
		Width="220px">
		<SelectedDayStyle BackColor="#666666" Font-Bold="True" ForeColor="White" />
		<SelectorStyle BackColor="#CCCCCC" />
		<WeekendDayStyle BackColor="#FFFFCC" />
		<TodayDayStyle BackColor="#CCCCCC" ForeColor="Black" />
		<OtherMonthDayStyle ForeColor="#808080" />
		<NextPrevStyle VerticalAlign="Bottom" />
		<DayHeaderStyle BackColor="#CCCCCC" Font-Bold="True" Font-Size="7pt" />
		<TitleStyle BackColor="#999999" BorderColor="Black" Font-Bold="True" />
	</asp:Calendar>

</td>

</tr></table>

<br /><br />
	
	<asp:Button ID=btnGenerateReport runat=server Text="Get Report" OnClick="btnGenerateReport_Click" />

<br /><br />

<asp:Literal ID=reportOutput runat=server EnableViewState=false  />
		
	</form>

<%-- ##########################################--%>
<asp:Literal ID=reportRowTemplate runat=server Visible=false>

<table width=800><tr valign=top>
<td width=30%>{~rowdate~}
</td>
<td width=8%>{~statusChange~}
</td>
<td width=18%>{~timeOfChange~}
</td>
<td width=40%>{~comments~}
</td></tr></table>

</asp:Literal>
	
</body>
</html>
