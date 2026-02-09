Option Explicit

Dim sourcePath, shortcutPath
Dim fso, sh, lnk, destination

If WScript.Arguments.Count < 2 Then WScript.Quit 1
sourcePath = WScript.Arguments(0)
shortcutPath = WScript.Arguments(1)

Set fso = CreateObject("Scripting.FileSystemObject")
Set sh = CreateObject("WScript.Shell")

If Not fso.FileExists(shortcutPath) Then
    MsgBox "Destination shortcut not found.", vbCritical, "Move To"
    WScript.Quit 1
End If

Set lnk = sh.CreateShortcut(shortcutPath)
destination = lnk.TargetPath

If destination = "" Or Not fso.FolderExists(destination) Then
    MsgBox "Destination folder is missing.", vbCritical, "Move To"
    WScript.Quit 1
End If

On Error Resume Next
If fso.FileExists(sourcePath) Then
    fso.MoveFile sourcePath, destination & "\"
ElseIf fso.FolderExists(sourcePath) Then
    fso.MoveFolder sourcePath, destination & "\"
Else
    MsgBox "Source item is missing.", vbCritical, "Move To"
    WScript.Quit 1
End If

If Err.Number <> 0 Then
    MsgBox "Move failed: " & Err.Description, vbCritical, "Move To"
    WScript.Quit 1
End If
On Error GoTo 0
