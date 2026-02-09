' MoveTo.vbs - Moves file/folder to destination using native Windows dialog
' Uses Shell.Application.MoveHere = same as Explorer drag & drop (native transfer)
' Handles: progress bar, conflicts, background transfer, cancel

Option Explicit

Dim sourcePath, destName
Dim wsh, fso, shell
Dim shortcutPath, lnk, destPath, destFolder

If WScript.Arguments.Count < 2 Then WScript.Quit 1
sourcePath = WScript.Arguments(0)
destName = WScript.Arguments(1)

Set wsh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

' Validate source exists
If Not fso.FileExists(sourcePath) And Not fso.FolderExists(sourcePath) Then WScript.Quit 1

' Resolve destination from shortcut
shortcutPath = "D:\Users\joty79\scripts\MoveTo\destinations\" & destName & ".lnk"
If Not fso.FileExists(shortcutPath) Then WScript.Quit 1

Set lnk = wsh.CreateShortcut(shortcutPath)
destPath = lnk.TargetPath
If destPath = "" Then WScript.Quit 1
If Not fso.FolderExists(destPath) Then WScript.Quit 1

' Move using native Windows Explorer mechanism
' MoveHere flag 0 = full native dialog (progress + conflict resolution)
Set shell = CreateObject("Shell.Application")
Set destFolder = shell.NameSpace(destPath)
If destFolder Is Nothing Then WScript.Quit 1

destFolder.MoveHere sourcePath, 0
