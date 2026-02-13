' MoveTo.vbs - Launch MoveTo Robocopy engine with marker deduplication
' Only first instance runs, others exit immediately.
' Stale markers (>5 min) auto-cleaned after crashes.

Option Explicit

Dim sourcePath, destName
Dim wsh, fso
Dim markerFile, f
Dim scriptRoot, destinationsFolder
Dim stageScriptPath, pasteScriptPath
Dim moveToLogPath

If WScript.Arguments.Count < 2 Then WScript.Quit 1
sourcePath = WScript.Arguments(0)
destName = WScript.Arguments(1)

Set wsh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
scriptRoot = fso.GetParentFolderName(WScript.ScriptFullName)
destinationsFolder = scriptRoot & "\destinations"
stageScriptPath = scriptRoot & "\Robocopy\rcopySingle.ps1"
pasteScriptPath = scriptRoot & "\Robocopy\rcp.ps1"
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

' Validate robocopy scripts
If (Not fso.FileExists(stageScriptPath)) Or (Not fso.FileExists(pasteScriptPath)) Then
    WriteLog "ERROR: robocopy scripts missing | stage='" & stageScriptPath & "' | paste='" & pasteScriptPath & "'"
    fso.DeleteFile markerFile, True
    WScript.Quit 1
End If

' Wait for other VBS instances to see marker and exit
WScript.Sleep 500

' Stage selected items in move mode (rcopySingle captures full Explorer selection)
safeSourcePath = Replace(sourcePath, """", """""")
stageCmd = "pwsh.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & stageScriptPath & """ mv """ & safeSourcePath & """"
stageExitCode = wsh.Run(stageCmd, 0, True)

' rcopySingle exit codes: 0 (single), 10 (multi-selection staged), others = failure
If stageExitCode <> 0 And stageExitCode <> 10 Then
    WriteLog "ERROR: staging failed | ExitCode=" & CStr(stageExitCode) & " | Source='" & sourcePath & "'"
    On Error Resume Next
    fso.DeleteFile markerFile, True
    On Error GoTo 0
    WScript.Quit 1
End If

' Execute move directly to selected destination
safeDestPath = Replace(destPath, """", """""")
pasteCmd = "pwsh.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & pasteScriptPath & """ mv s """ & safeDestPath & """ __moveto"
pasteExitCode = wsh.Run(pasteCmd, 0, True)
If pasteExitCode <> 0 Then
    WriteLog "ERROR: paste failed | ExitCode=" & CStr(pasteExitCode) & " | Dest='" & destPath & "'"
End If

' Cleanup marker after move flow exits
On Error Resume Next
fso.DeleteFile markerFile, True
On Error GoTo 0

WScript.Quit pasteExitCode
