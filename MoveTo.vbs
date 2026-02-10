' MoveTo.vbs - Simplest possible: Ctrl+X, open dest, Ctrl+V, EXIT
' Zero clipboard manipulation, zero COM during transfer.
' wscript.exe exits immediately — Explorer handles everything.

Option Explicit

Dim sourcePath, destName
Dim wsh, fso
Dim markerFile, f

If WScript.Arguments.Count < 2 Then WScript.Quit 1
sourcePath = WScript.Arguments(0)
destName = WScript.Arguments(1)

Set wsh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

' ===== Marker: only first instance proceeds =====
markerFile = wsh.ExpandEnvironmentStrings("%TEMP%") & "\MoveTo_" & destName & ".marker"

On Error Resume Next
Set f = fso.CreateTextFile(markerFile, False)
If Err.Number <> 0 Then WScript.Quit 0
On Error GoTo 0
f.Close

' ===== Resolve destination =====
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

' ===== Debug log =====
Dim logFile, logStream
logFile = wsh.ExpandEnvironmentStrings("%TEMP%") & "\MoveTo_debug.log"
Set logStream = fso.OpenTextFile(logFile, 8, True)
logStream.WriteLine FormatDateTime(Now, 3) & " | START"
logStream.WriteLine FormatDateTime(Now, 3) & " | Dest: " & destPath

' ===== Step 1: Ctrl+X (source window is active from right-click) =====
wsh.SendKeys "^x"
WScript.Sleep 500
logStream.WriteLine FormatDateTime(Now, 3) & " | Ctrl+X sent"

' ===== Step 2: Open destination =====
Dim shell
Set shell = CreateObject("Shell.Application")
shell.Open destPath
logStream.WriteLine FormatDateTime(Now, 3) & " | Destination opened"

' Release ALL COM immediately
Set shell = Nothing

' Wait for destination window to load
WScript.Sleep 1200

' ===== Step 3: Ctrl+V (destination window is now foreground) =====
wsh.SendKeys "^v"
logStream.WriteLine FormatDateTime(Now, 3) & " | Ctrl+V sent"
logStream.WriteLine FormatDateTime(Now, 3) & " | END"
logStream.Close

' ===== Cleanup marker and EXIT =====
On Error Resume Next
fso.DeleteFile markerFile, True
On Error GoTo 0

' wscript.exe exits — ZERO COM references held during transfer
' Explorer handles everything natively via IFileOperation
