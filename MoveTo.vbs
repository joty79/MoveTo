' MoveTo.vbs - Native clipboard CUT + paste approach
' Only first instance runs (marker file), others exit immediately

Option Explicit

Dim sourcePath, destName
Dim wsh, fso
Dim markerFile, f

If WScript.Arguments.Count < 2 Then WScript.Quit 1
sourcePath = WScript.Arguments(0)
destName = WScript.Arguments(1)

Set wsh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

' Marker: only first instance proceeds, others exit
markerFile = wsh.ExpandEnvironmentStrings("%TEMP%") & "\MoveTo_" & destName & ".marker"

On Error Resume Next
Set f = fso.CreateTextFile(markerFile, False)
If Err.Number <> 0 Then
    ' Another instance already handling this - exit
    WScript.Quit 0
End If
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

' Wait for all other VBS instances to see the marker and exit
WScript.Sleep 300

' Spawn PS1 to do native clipboard CUT + paste (fire and forget)
Dim cmd
cmd = "pwsh.exe -NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File ""D:\Users\joty79\scripts\MoveTo\MoveTo.ps1"" """ & sourcePath & """ """ & destPath & """"
wsh.Run cmd, 0, False

' Cleanup marker
On Error Resume Next
fso.DeleteFile markerFile, True
On Error GoTo 0
