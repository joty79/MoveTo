' MoveTo.vbs - Marker check + launch compiled exe
' Only first instance runs, others exit immediately.
' Stale markers (>5 min old) are auto-cleaned.

Option Explicit

Dim sourcePath, destName
Dim wsh, fso
Dim markerFile, f

If WScript.Arguments.Count < 2 Then WScript.Quit 1
sourcePath = WScript.Arguments(0)
destName = WScript.Arguments(1)

Set wsh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

' Marker: only first instance proceeds
markerFile = wsh.ExpandEnvironmentStrings("%TEMP%") & "\MoveTo_" & destName & ".marker"

' Clean stale markers (older than 5 minutes = stuck from crash)
If fso.FileExists(markerFile) Then
    Dim mFile, age
    Set mFile = fso.GetFile(markerFile)
    age = DateDiff("s", mFile.DateLastModified, Now)
    If age > 300 Then
        fso.DeleteFile markerFile, True
    End If
End If

' Try to claim marker
On Error Resume Next
Set f = fso.CreateTextFile(markerFile, False)
If Err.Number <> 0 Then WScript.Quit 0
On Error GoTo 0
f.Close

' Resolve destination from shortcut
Dim shortcutPath, lnk, destPath
shortcutPath = "D:\Users\joty79\scripts\MoveTo\destinations\" & destName & ".lnk"
If Not fso.FileExists(shortcutPath) Then
    fso.DeleteFile markerFile, True
    WScript.Quit 1
End If

Set lnk = wsh.CreateShortcut(shortcutPath)
destPath = lnk.TargetPath

If destPath = "" Or Not fso.FolderExists(destPath) Then
    fso.DeleteFile markerFile, True
    WScript.Quit 1
End If

' Wait for other instances to exit
WScript.Sleep 500

' Delete marker BEFORE launching exe — exe handles its own lifetime
On Error Resume Next
fso.DeleteFile markerFile, True
On Error GoTo 0

' Launch compiled exe (proper STAThread + message pump)
Dim cmd
cmd = """D:\Users\joty79\scripts\MoveTo\MoveTo.exe"" """ & sourcePath & """ """ & destPath & """"
wsh.Run cmd, 0, False
