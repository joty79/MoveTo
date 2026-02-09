' MoveTo.vbs - Collector wrapper for Move To context menu
' Collects paths into temp file, last instance spawns MoveTo.ps1

Option Explicit

Dim sourcePath, destName
Dim fso, objShell
Dim tempFile, lockFile

If WScript.Arguments.Count < 2 Then WScript.Quit 1
sourcePath = WScript.Arguments(0)
destName = WScript.Arguments(1)

Set fso = CreateObject("Scripting.FileSystemObject")
Set objShell = CreateObject("WScript.Shell")

tempFile = objShell.ExpandEnvironmentStrings("%TEMP%") & "\MoveTo_paths.txt"
lockFile = objShell.ExpandEnvironmentStrings("%TEMP%") & "\MoveTo.lock"

' Resolve destination from shortcut
Dim destinationsFolder, shortcutPath, lnk, destPath
destinationsFolder = "D:\Users\joty79\scripts\MoveTo\destinations"
shortcutPath = destinationsFolder & "\" & destName & ".lnk"

If Not fso.FileExists(shortcutPath) Then WScript.Quit 1

Set lnk = objShell.CreateShortcut(shortcutPath)
destPath = lnk.TargetPath

If destPath = "" Then WScript.Quit 1
If Not fso.FolderExists(destPath) Then WScript.Quit 1

' Validate source
If Not fso.FileExists(sourcePath) And Not fso.FolderExists(sourcePath) Then WScript.Quit 1

' Write to temp file: destination|source
Dim ts
Set ts = fso.OpenTextFile(tempFile, 8, True)
ts.WriteLine destPath & "|" & sourcePath
ts.Close

' Wait for other instances to write
WScript.Sleep 400

' Try to acquire lock
Dim lockAcquired, lockStream
lockAcquired = False

On Error Resume Next
Set lockStream = fso.OpenTextFile(lockFile, 2, True)
If Err.Number = 0 Then
    lockStream.Write "locked"
    lockStream.Close
    lockAcquired = True
End If
On Error GoTo 0

If lockAcquired Then
    ' Wait a bit more for stragglers
    WScript.Sleep 300

    ' Spawn MoveTo.ps1 (hidden) to do the actual moves
    Dim cmd
    cmd = "pwsh.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File ""D:\Users\joty79\scripts\MoveTo\MoveTo.ps1"""
    objShell.Run cmd, 0, True

    ' Cleanup lock
    On Error Resume Next
    fso.DeleteFile lockFile, True
    On Error GoTo 0
End If
