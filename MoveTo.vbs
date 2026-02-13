' MoveTo.vbs - Launch MoveTo Robocopy engine with marker deduplication
' Only first instance runs, others exit immediately.
' Stale markers (>5 min) auto-cleaned after crashes.

Option Explicit

Dim sourcePath, destName
Dim wsh, fso
Dim markerFile, f
Dim scriptRoot, destinationsFolder
Dim stageScriptPath, pasteScriptPath, stageWrapperPath, pasteWrapperPath
Dim moveToLogPath

If WScript.Arguments.Count < 2 Then WScript.Quit 1
sourcePath = WScript.Arguments(0)
destName = WScript.Arguments(1)

Set wsh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
scriptRoot = fso.GetParentFolderName(WScript.ScriptFullName)
destinationsFolder = scriptRoot & "\destinations"
stageScriptPath = scriptRoot & "\rcopySingle.ps1"
pasteScriptPath = scriptRoot & "\rcp.ps1"
stageWrapperPath = scriptRoot & "\RoboCopy_Silent.vbs"
pasteWrapperPath = scriptRoot & "\RoboPaste_Admin.vbs"
moveToLogPath = wsh.ExpandEnvironmentStrings("%TEMP%") & "\MoveTo_debug.log"

Sub WriteLog(ByVal msg)
    On Error Resume Next
    Dim ts
    Set ts = fso.OpenTextFile(moveToLogPath, 8, True, 0)
    ts.WriteLine CStr(Now) & " | " & msg
    ts.Close
    On Error GoTo 0
End Sub

' Marker: only first instance proceeds
markerFile = wsh.ExpandEnvironmentStrings("%TEMP%") & "\MoveTo_" & destName & ".marker"

' Clean stale markers (older than 5 min = stuck from crash)
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
Dim shortcutPath, lnk, destPath, stageCmd, pasteCmd
Dim safeSourcePath, safeDestPath
Dim stageExitCode, pasteExitCode

shortcutPath = destinationsFolder & "\" & destName & ".lnk"
If Not fso.FileExists(shortcutPath) Then
    WriteLog "ERROR: missing shortcut '" & shortcutPath & "'"
    fso.DeleteFile markerFile, True
    WScript.Quit 1
End If

Set lnk = wsh.CreateShortcut(shortcutPath)
destPath = lnk.TargetPath

If destPath = "" Or Not fso.FolderExists(destPath) Then
    WriteLog "ERROR: invalid destination for '" & destName & "' -> '" & destPath & "'"
    fso.DeleteFile markerFile, True
    WScript.Quit 1
End If

' Validate robocopy scripts + wrappers
If (Not fso.FileExists(stageScriptPath)) Or (Not fso.FileExists(pasteScriptPath)) Or (Not fso.FileExists(stageWrapperPath)) Or (Not fso.FileExists(pasteWrapperPath)) Then
    WriteLog "ERROR: robocopy runtime missing | stage='" & stageScriptPath & "' | paste='" & pasteScriptPath & "' | stageWrapper='" & stageWrapperPath & "' | pasteWrapper='" & pasteWrapperPath & "'"
    fso.DeleteFile markerFile, True
    WScript.Quit 1
End If

' Wait for other VBS instances to see marker and exit
WScript.Sleep 500

' Stage selected items via the same silent Robo-Cut wrapper flow as standalone Robocopy
safeSourcePath = Replace(sourcePath, """", """""")
stageCmd = "wscript.exe """ & stageWrapperPath & """ mv """ & safeSourcePath & """"
stageExitCode = wsh.Run(stageCmd, 0, True)

' Wrapper should normally return 0. Keep fail-fast if shell returns failure.
If stageExitCode <> 0 Then
    WriteLog "ERROR: staging failed | ExitCode=" & CStr(stageExitCode) & " | Source='" & sourcePath & "'"
    On Error Resume Next
    fso.DeleteFile markerFile, True
    On Error GoTo 0
    WScript.Quit 1
End If

' Launch the same elevated Robo-Paste wrapper flow as standalone Robocopy.
safeDestPath = Replace(destPath, """", """""")
pasteCmd = "wscript.exe """ & pasteWrapperPath & """ """ & safeDestPath & """"
pasteExitCode = wsh.Run(pasteCmd, 0, False)
WriteLog "INFO: launched Robo-Paste wrapper | Dest='" & destPath & "'"

' Cleanup marker after move flow exits
On Error Resume Next
fso.DeleteFile markerFile, True
On Error GoTo 0

WScript.Quit 0
