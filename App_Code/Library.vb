Option Strict On : Option Explicit On : Option Infer On : Option Compare Binary

Imports System.IO
Imports System.Collections.Generic
Imports System.Text.RegularExpressions
Imports System.Net

Namespace System		' namespace "pollution"

	Public Class Constant
		Public Const onespace As String = " "
		Public Const twospaces As String = "  "
		Public Const singlequote As String = "'"		'		Public Const tick As String = "'"
		Public Const doublequote As String = """"
		Public Const backslash As String = "\"
		Public Const underscore As String = "_"
	End Class

	Public Class Assert

		' [System.Diagnostics.Conditional("DEBUG")] // <== ideally, each assertion is #if DEBUG wrapped at callsite 
		Shared Sub [True](ByVal mustBeTrue As Boolean)
			If mustBeTrue Then Return

			Throw New ApplicationException()
		End Sub

		Shared Sub [True](ByVal mustBeTrue As Boolean, ByVal exceptionMsg As String)
			If Not mustBeTrue Then Throw New ApplicationException(exceptionMsg)
		End Sub

		Shared Sub HasValue(ByVal s As String)
			If String.IsNullOrEmpty(s) OrElse s.Length = 0 Then Throw New ApplicationException()
		End Sub

		Shared Sub IsPositive(ByVal i As Integer)
			If i <= 0 Then Throw New ApplicationException()
		End Sub

		Shared Sub NotNull(ByVal o As Object)
			If o Is Nothing Then Throw New ApplicationException()
		End Sub

	End Class

End Namespace

Namespace Library

	Public Class Tools

		''' <summary>
		''' do global replace of {~~} delim'd placeholder(s) in template; case-sensitive
		''' </summary>
		'''
		Shared Function Templatize(ByRef template As String, ByVal ParamArray namesAndContent As String()) As String
			' down-n-dirty, no placeholdername or content checks

			Assert.True(namesAndContent.Length Mod 2 = 0)

			Dim result As New System.Text.StringBuilder(template)
			For x As Integer = 0 To namesAndContent.Length - 1 Step 2

				Dim placeholder As String = "{~" & namesAndContent(x) & "~}"
				Dim content As String = namesAndContent(x + 1)

				result.Replace(placeholder, content) ' *** problem? consider case-sensitivity
			Next

			Return result.ToString
		End Function

		Shared Function Trunc(ByVal s As String, ByVal maxlen As Integer) As String
			If maxlen < 1 OrElse String.IsNullOrEmpty(s) Then Return s

			Return s.Substring(0, Math.Min(maxlen, s.Length))
		End Function

		Shared Function Pathsafe(ByVal s As String) As String
			s = Regex.Replace(s, "[|""*?:/\\]", "_")
			Return s
		End Function

		Shared Sub StripCRandLF(ByRef content As String)

			content = content.Replace(vbCr, Constant.onespace).Replace(vbLf, Constant.onespace)	' output may rely on CR and/or LF for HTML spacemaking 
			content = content.Replace(Constant.twospaces, Constant.onespace)	     ' two spaces -> one 
			' shockingly inefficient 
		End Sub

		Shared Function ParsedAndWithinRange(ByVal possibleInteger As String, ByVal inclusiveLowerbound As Integer, ByVal inclusiveUpperbound As Integer) As System.Nullable(Of Integer)
			Dim parsedInt As Integer
			If Int32.TryParse(possibleInteger, parsedInt) AndAlso parsedInt >= inclusiveLowerbound AndAlso parsedInt <= inclusiveUpperbound Then
				Return parsedInt
			End If

			Return Nothing
		End Function

		''' <summary>
		''' directory file list with multiple search patterns, e.g. "*.bmp;*.gif;*.jpg" etc.
		''' </summary>
		'''
		Shared Function DirectoryGetFiles(ByVal path As String, ByVal wildcardSearchPatterns As String) As String()

			Dim extensions As String() = wildcardSearchPatterns.Split(";"c)
			Dim files As New List(Of String)
			For Each ext In extensions

				files.AddRange(System.IO.Directory.GetFiles(path, ext.Trim))
			Next

			Return files.ToArray
		End Function

		Shared Sub WriteFile(ByVal contents As String, ByVal filepath As String)
			' overwrite existing 
			Assert.HasValue(filepath)

			Using file As New FileStream(filepath, FileMode.Create, FileAccess.Write)
				Using sw As New StreamWriter(file)
					sw.Write(contents)
				End Using
			End Using

		End Sub

		Shared Sub AppendFile(ByVal contents As String, ByVal filepath As String)
			' append/create 
			Assert.HasValue(filepath)

			Using file As New FileStream(filepath, FileMode.Append, FileAccess.Write)
				Using sw As New StreamWriter(file)
					sw.Write(contents)
				End Using
			End Using
		End Sub

		''' <summary>
		''' compare only year|month|day of two dates; equal?
		''' </summary>
		'''
		Shared Function DateEqualsTimeless(ByRef date1 As Date, ByRef date2 As Date) As Boolean
			Return (date1.Year = date2.Year AndAlso date1.Month = date2.Month AndAlso date1.Day = date2.Day)
		End Function

		''' <summary>
		''' fast case-insensitive string contains substring check (ordinal rules)
		''' </summary>
		'''
		Shared Function StrContains(ByRef mainstring As Object, ByRef substring As String) As Boolean
			Return (mainstring.ToString.IndexOf(substring, StringComparison.OrdinalIgnoreCase) >= 0)
		End Function

		''' <summary>
		''' fast case-insensitive string comparison (ordinal rules)
		''' </summary>
		'''
		Shared Function StrEqual(ByRef s1 As String, ByRef s2 As String) As Boolean
			Return String.Equals(s1, s2, StringComparison.OrdinalIgnoreCase)
		End Function

		''' <summary>
		''' trim string object which may be null
		''' </summary>
		'''
		Shared Function Trim(ByVal s As String) As String
			If String.IsNullOrEmpty(s) Then Return s

			Return s.Trim
		End Function

		''' <summary>
		''' before serving HTML, do standard HTMLEncode [open bracket, ampersand, and quote]
		''' plus single-quote (for JS-strings) and % (defeat URL-decoding) ; consider also doing ":" colon
		''' </summary>	
		Shared Function HTMLEncodeExtra(ByVal s As String) As String
			If String.IsNullOrEmpty(s) Then Return s

			s = HttpContext.Current.Server.HtmlEncode(s) ' standard

			s = s.Replace(Constant.singlequote, "&#39;") ' do single quote
			s = s.Replace("%", "&#37;") ' do %
			' do :   ?????

			Return s				' untouched are [ !@#$^*()-_=+\][|}{;:., ]
		End Function

		''' <summary>
		''' ensure only single-space, then trim
		''' </summary>
		'''
		Shared Function SuperTrim(ByVal s As String) As String
			If String.IsNullOrEmpty(s) Then Return s

			While s.Contains("  ") ' doublespace?
				s = s.Replace("  ", " ")
			End While

			Return s.Trim
		End Function


		Shared Function Stream2ByteArray(ByRef stream As System.IO.Stream) As Byte()
			Dim streamLength As Integer = CInt(stream.Length)
			Dim fileData As Byte() = New Byte(streamLength) {}

			stream.Read(fileData, 0, streamLength)
			stream.Close()

			Return fileData
		End Function

		''' <summary>
		''' utility function - convert byte array to hex string
		''' </summary>
		'''
		Shared Function ByteArrayToHexString(ByVal arrInput() As Byte) As String

			Dim strOutput As New System.Text.StringBuilder(arrInput.Length * 2) ' num chars

			For i As Integer = 0 To arrInput.Length - 1
				strOutput.Append(arrInput(i).ToString("X2")) ' uppercase hex
			Next

			Return strOutput.ToString()

			' EQUIVALENT CODE  (another way using BitConverter)
			'		Dim sb As New System.Text.StringBuilder(BitConverter.ToString(ba))
			'		sb.Replace("-", "")
			'		Return sb.ToString()

		End Function

		''' <summary>
		''' return JavaScript-ready tick-wrapped (') string
		''' </summary>
		'''
		Shared Function JavaScriptSafe(ByVal s As String, _
		Optional ByVal appendNewline As Boolean = False, _
		Optional ByVal BReaks2Newlines As Boolean = False) As String

			If String.IsNullOrEmpty(s) Then Return Constant.singlequote & Constant.singlequote & _
			 If(appendNewline, vbCrLf, String.Empty)

			s = s.Trim
			Dim jsStr As String

			jsStr = Regex.Replace(s, "[\r\v\f\n]", " ") ' all linebreaks to space (HTML cannot contain clientside SCRIPT tag -- BUT CAN CONTAIN eventhandlers e.g. onclick="..")
			jsStr = Replace(jsStr, vbTab, " ")	  ' tab to space
			jsStr = Regex.Replace(jsStr, "[ ]{2,}", " ")	' single-space everywhere

			Assert.True(Not jsStr.Contains(vbCr))
			Assert.True(Not jsStr.Contains(vbLf))
			Assert.True(Not jsStr.Contains(vbTab))

			' [old]  \\\ no \\divide into 128-char lines 			' Dim x As Integer = 0 ' string.substring zero-based (?)
			'					Do While x < jsStr.Length				If sb.Length > 0 Then sb.Append(vbCrLf & "+ ")
			'					 encode chars to escape sequence, keeping on same line '		Dim nextLine As String = jsStr.Substring(x, Math.Min(128, jsStr.Length - x))

			' encode \ for JS
			jsStr = Regex.Replace(jsStr, "\\", "\\")	' last arg is plain string: literally two \s

			' <br>  ==>  \n
			If BReaks2Newlines Then jsStr = Regex.Replace(jsStr, "\<br\s*[/]?\>", "\n", RegexOptions.IgnoreCase)

			' encode ' tick/singlequote
			jsStr = Regex.Replace(jsStr, "[']", "\'")	' last arg is literally backslash+tick

			' ****** ? upper ASCII + Unicode ?? ***************************

			Return String.Concat(Constant.singlequote, jsStr, Constant.singlequote, _
			 If(appendNewline, vbCrLf, String.Empty))

		End Function

	End Class

	Public Class _UnusedTools

		Shared Sub StripTags(ByRef content As String)
			content = Regex.Replace(content, "<\/?\w+[^>]*>", "")
			' can't handle, e.g., <namespace:tagname...> 
		End Sub

		Shared Function HasNoHTMLTags(ByRef s As String) As Boolean
			If s.Contains("<") OrElse s.Contains(">") Then Return False
			' ignore encoded forms: &lt; etc. 

			Return True
		End Function

		Shared Function GetHTTPString(ByVal Url As String) As String
			' may return nullstring 
			Dim downloaded As String = ""

			' wait a bit, don't hammer the provider 
			System.Threading.Thread.Sleep(800)
			' milliseconds ; arbitrary hardcoded limit 
			Try
				Dim httpWR As HttpWebRequest = DirectCast(HttpWebRequest.Create(Url), HttpWebRequest)
				' HTTP GET occurs 
				' alternative: WebClient class -- "string result = webClient.DownloadString(url);" 
				httpWR.UserAgent = ".NET Framework"
				' httpWR.Referer = ""
				httpWR.Timeout = 1000 * 60 * 6
				' milliseconds (6 mins.) // TODO: gracefully deal with hardcoded limits 
				Dim resp As WebResponse = httpWR.GetResponse()
				Dim WebStream As Stream = resp.GetResponseStream()
				Dim Reader As New StreamReader(WebStream)
				downloaded = Reader.ReadToEnd()
			Catch ex As Exception
			End Try

			Return downloaded
		End Function

		' Shared Function GetHTTPImage(ByVal src As String) As Byte()
		'	' may return null // TODO: extract hardcoded constants 
		'	Dim img As Byte()
		'	Dim buffer As Byte() = New Byte(199999) {}
		'	' nasty hardcoded maximum length 
		'	Dim read As Integer, total As Integer = 0

		'	System.Threading.Thread.Sleep(800)
		'	' wait a bit, don't hammer the provider 
		'	Try
		'		Dim req As HttpWebRequest = DirectCast(WebRequest.Create(src), HttpWebRequest)
		'		' HTTP GET occurs 
		'		req.Timeout = 1000 * 60 * 6
		'		' milliseconds (6 mins.) 
		'		Dim resp As WebResponse = req.GetResponse()
		'		Dim stream As Stream = resp.GetResponseStream()

		'		While (total + 1000) < buffer.Length AndAlso (read = stream.Read(buffer, total, 1000)) <> 0
		'			total += read
		'		End While
		'	Catch ex As Exception
		'	End Try

		'	' TODO: check that bytestream, if any, is an image 

		'	If total = 0 Then
		'		Return Nothing
		'	Else
		'		'caller must handle nullness 
		'		img = New Byte(total - 1) {}
		'		System.Array.Copy(buffer, img, total)
		'		Return img
		'	End If
		'End Function

		Shared Function MeatOfStringSandwich(ByVal s As String, ByVal opener As String, ByVal closer As String) As String
			' truncate up to and including an opener string, then including and trailing a closer string 
			Dim temp As String = ""

			If s.Contains(opener) AndAlso s.Contains(closer) Then
				temp = s.Substring(s.IndexOf(opener) + opener.Length)
				temp = temp.Substring(0, temp.IndexOf(closer))
			End If

			Return temp
		End Function

		Shared Sub StripDoubledOpenTags(ByRef content As String, ByVal tagName As String)
			' because ABC/Yahoo output sometimes contains: <div blah blah><div> or <a blah><a blah> etc. 
			' ideally, all assertions would be #if DEBUG wrapped, like: 
#If DEBUG Then
        Assert.True(Not String.IsNullOrEmpty(content)) 
        Assert.True(Not String.IsNullOrEmpty(tagName)) 
#End If

			Dim reStr As String = String.Format("<{0}[^>]*?>\s*(<{0}[^>]*?>)+", tagName)

			content = Regex.Replace(content, reStr, "", RegexOptions.IgnoreCase)
		End Sub

		Shared Sub FlattenHTMLElement(ByRef content As String, ByVal tagName As String)
			' remove (balanced) tag, leave text ; ignores empty elements, <hr> | <br/> etc. and textless, e.g., <p></p> 
			Dim reStr As String = String.Format("(<{0}\s*[^>]*?>)(.+?)(</{0}\s*?>)+", tagName)
			' capture multiple close tags, to handle e.g.: <a><a>..</a></a> 

			content = Regex.Replace(content, reStr, "$2", RegexOptions.IgnoreCase Or RegexOptions.Singleline)
		End Sub

		Shared Sub StripSoloHTMLTag(ByRef content As String, ByVal tagToStrip As String)
			' remove tag of empty element like <hr> | <br/> etc. 
			Dim reStr As String = String.Format("(<{0}\s+[^>]+?>)", tagToStrip)

			content = Regex.Replace(content, reStr, "", RegexOptions.IgnoreCase)
		End Sub

		Shared Function NormalizeXHTMLParas(ByVal content As String) As String
			' ensure all text conforms: <p> .. </p> 
			Assert.HasValue(content)
			' do not return <p></p> 
			' use \t as temporary para delimiter 
			content = content.Replace(vbTab, "")
			' sterilize content of the delim char 
			content = content.Replace("</p>", vbTab)
			' open P everywhere // TODO: worry about uppercase <P> 
			content = content.Replace("<p>", vbTab)

			content = Regex.Replace(content, "\s+\t", vbTab, RegexOptions.IgnoreCase)
			' no whitespace before P 
			content = Regex.Replace(content, "\t\s+", vbTab, RegexOptions.IgnoreCase)
			' no whitespace after P 
			content = vbTab + content + vbTab
			' guarantee delim at open/close 
			While content.Contains(vbTab & vbTab)
				content = content.Replace(vbTab & vbTab, vbTab)
				' strip empty paras and redundant opener/closer // TODO: worry about <!--comments--> 
			End While

			' get each chunk between paras 
			Dim reParas As New Regex("\t([^\t]+)")
			' do not include next delim, otherwise regex would overlap 
			Dim mc As MatchCollection = reParas.Matches(content)
			' could alternatively do string.Split() splitting by \t char 

			If mc.Count = 0 Then
				Return ""
			End If
			' no paras 
			Dim sb As New System.Text.StringBuilder()

			For Each m As Match In mc
				Dim chunk As String = m.Groups(1).Value.Trim()
				If chunk.Length > 0 Then
					Tools.StripCRandLF(chunk)
					chunk = chunk.Replace("<br>", "<br/>")
					' XHTMLize 
					sb.Append("<p>" + chunk + "</p>" + Environment.NewLine)
				End If
			Next

			Return sb.ToString()
		End Function

		' Shared Sub StripControlChars(ByRef content As String)
		'	If String.IsNullOrEmpty(content) OrElse content.Length = 0 Then
		'		Return
		'	End If

		'	Dim sb As New StringBuilder()
		'	For idx As Integer = 0 To content.Length - 1
		'		If CInt(content(idx)) >= 32 Then
		'			sb.Append(content(idx))
		'		End If
		'	Next
		'	' if space or higher add char 
		'	content = sb.ToString()
		'End Sub

	End Class

	Public Class Templatizer

		Const opener As String = "{~", closer As String = "~}"

		ReadOnly t As System.Text.StringBuilder	' the template 
		ReadOnly tString As String	' for speedy searching (DEBUG only) 
		ReadOnly placeholders As Dictionary(Of String, String)

		Sub New(ByVal template As String)
			' template not empty? 
			Assert.True(template IsNot Nothing AndAlso template.Length > 0)
			' template has at least one placeholder? 
			Assert.True(template.Contains(opener))
			Assert.True(template.Contains(closer))

			t = New System.Text.StringBuilder(template)
			tString = template
			' save for searching of placeholdernames (DEBUG) 
			placeholders = New Dictionary(Of String, String)()
		End Sub

		Sub AddContent(ByVal placeholdername As String, ByVal content As String)

			Assert.True(placeholders IsNot Nothing)		' this constructed successfully? 
			Assert.True(Not String.IsNullOrEmpty(placeholdername))		' NOTE: OK if content is blank 

			' unique name? 
			Assert.True(Not placeholders.ContainsKey(placeholdername))

			' template text contains this placeholder name? 
			Assert.True(tString.IndexOf( _
			  opener & placeholdername & closer, 0, StringComparison.CurrentCultureIgnoreCase) > -1, "no placeholder: " + placeholdername)

			placeholders.Add(placeholdername, content)

			'TODO: add option to html-extra encode content
		End Sub

		Function GetResult() As String
			Assert.True(placeholders.Count <> 0)

			Dim de As Dictionary(Of String, String).Enumerator = placeholders.GetEnumerator()

			While de.MoveNext()
				t.Replace(opener + de.Current.Key + closer, de.Current.Value)
			End While

			Dim result As String = t.ToString()
			' all placeholders replaced? 
			Assert.True(Not result.Contains(opener))
			Assert.True(Not result.Contains(closer))

			Return result
		End Function
	End Class

	Public Class ResizedJPEG

		Public ReadOnly byteArray As Byte()
		Public ReadOnly actualSize As System.Drawing.Size
		Public ReadOnly dimensionString As String

		Sub New(ByVal desiredWidth As Integer, ByVal desiredClipHeight As Integer, ByVal jpegQuality As Long, ByVal sourceImage As Byte())

			' create resized image from bytestream 
			Using ms As New MemoryStream(sourceImage)

				Dim i As System.Drawing.Image = System.Drawing.Image.FromStream(ms)
				Dim pr As New PhotoResizing(desiredWidth, desiredClipHeight, New System.Drawing.Size(i.Width, i.Height))

				i = ResizeImage(pr, i)
				Me.byteArray = GetJPEGBytestream(i, jpegQuality)
				Me.actualSize = New System.Drawing.Size(i.Width, i.Height)
				Me.dimensionString = String.Concat(actualSize.Width, "x", actualSize.Height)

				i.Dispose()	' academic 

			End Using
		End Sub

		Public Shared Function WidthFromDimensionString(ByVal dimensions As String) As Integer
			Return CInt(dimensions.Split("x"c)(0))
		End Function

		Private Function GetJPEGBytestream(ByVal source_i As System.Drawing.Image, ByVal quality As Long) As Byte()

			Dim b As New System.Drawing.Bitmap(source_i)
			Dim encoders As System.Drawing.Imaging.ImageCodecInfo() = System.Drawing.Imaging.ImageCodecInfo.GetImageEncoders()
			Dim encPrms As New System.Drawing.Imaging.EncoderParameters(1)
			encPrms.Param(0) = New System.Drawing.Imaging.EncoderParameter(System.Drawing.Imaging.Encoder.Quality, quality)

			Dim ms As New System.IO.MemoryStream()

			For Each encoderX As System.Drawing.Imaging.ImageCodecInfo In encoders
				If encoderX.MimeType = "image/jpeg" Then
					b.Save(ms, encoderX, encPrms)
					Exit For
				End If
			Next
			b.Dispose()
			encPrms.Dispose()

			Return ms.ToArray()
		End Function

		Private Shared Function ResizeImage(ByVal pr As PhotoResizing, ByVal i As System.Drawing.Image) As System.Drawing.Image

			Dim b As New System.Drawing.Bitmap(pr.renderSize.Width, pr.renderSize.Height)
			' ^ code elsewhere should Dispose() 

			Using g As System.Drawing.Graphics = System.Drawing.Graphics.FromImage(b)

				g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic
				g.PixelOffsetMode = System.Drawing.Drawing2D.PixelOffsetMode.HighQuality
				g.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.HighQuality

				g.DrawImage(i, 0, 0, pr.renderSize.Width, pr.renderSize.Height)			' draw full-height image on fixed-height bitmap 
				g.Flush()			' fill the bitmap 
				Return b
			End Using
		End Function

		Private Structure PhotoResizing

			Private ReadOnly origSize As System.Drawing.Size
			Public ReadOnly renderSize As System.Drawing.Size

			Sub New(ByVal newWidth As Integer, ByVal newHeight As Integer, ByVal origSize As System.Drawing.Size)
				' newHeight is the clipping (max) height 

				Me.origSize = origSize
				' [ always blowup width ] newWidth = FriendlyWidth(newWidth, origSize, canBlowUpWidth); 

				' needed for proportional drawing 
				Dim idealHeight As Integer = (origSize.Height * newWidth) \ origSize.Width
				' real proportioned height 
				Dim realHeight As Integer = GetClippedHeight(origSize.Width, origSize.Height, newWidth, newHeight)

				Me.renderSize = New System.Drawing.Size(newWidth, realHeight)
			End Sub

			Private Function FriendlyWidth(ByVal newWidth As Integer, ByVal origSize As System.Drawing.Size, ByVal canBlowup As Boolean) As Integer

				Dim fw As Integer = 0
				If canBlowup Then fw = newWidth Else fw = Math.Min(origSize.Width, newWidth) '  keep orig width if smaller 

				Return fw
			End Function

			Shared Function GetClippedHeight(ByVal oldW As Integer, ByVal oldH As Integer, ByVal newW As Integer, ByVal clippingH As Integer) As Integer
				Dim newH As Integer = (oldH * newW) \ oldW ' truncating int division 
				If clippingH > 0 Then
					newH = Math.Min(newH, clippingH)
				End If
				' lop off the bottom 
				Return newH
			End Function

		End Structure

	End Class

	'Namespace ExtensionMethods
	'	Module Ext

	'		<System.Runtime.CompilerServices.Extension()> _
	'		Public Function Singlequote(ByRef s As String) As String
	'			Return "'"
	'		End Function

	'		'  allows					Return ("").Singlequote

	'	End Module
	'End Namespace

End Namespace
