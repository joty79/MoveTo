' MoveTo.vbs - ALL-IN-ONE (no PowerShell needed)
' Marker check + COM MoveHere directly from wscript.exe
' wscript.exe has native STA message pump — proper COM hosting.

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
If Err.Number <> 0 Then
    ' Another instance already handling this
    WScript.Quit 0
End If
On Error GoTo 0
f.Close

' ===== Resolve destination from shortcut =====
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

' Wait for all other VBS instances to see marker and exit
WScript.Sleep 500

' ===== THE MOVE — pure COM, no PowerShell =====
Dim shell, sourceParent
Set shell = CreateObject("Shell.Application")
sourceParent = fso.GetParentFolderName(sourcePath)

' Debug log
Dim logFile, ts
logFile = wsh.ExpandEnvironmentStrings("%TEMP%") & "\MoveTo_debug.log"
ts = FormatDateTime(Now, 3)

Dim logStream
Set logStream = fso.OpenTextFile(logFile, 8, True)
logStream.WriteLine ts & " | START | Source: " & sourcePath
logStream.WriteLine ts & " | Dest: " & destPath

' Find Explorer window with selected items
Dim win, winPath, selectedItems, destFolder
For Each win In shell.Windows
    On Error Resume Next
    winPath = win.Document.Folder.Self.Path
    If Err.Number = 0 Then
        If winPath = sourceParent Then
            Set selectedItems = win.Document.SelectedItems
            logStream.WriteLine ts & " | Selected: " & selectedItems.Count & " items"

            If selectedItems.Count > 0 Then
                Set destFolder = shell.NameSpace(destPath)
                If Not destFolder Is Nothing Then
                    logStream.WriteLine ts & " | Calling MoveHere..."

                    ' MoveHere entire FolderItems collection — ONE operation
                    destFolder.MoveHere selectedItems, 0

                    logStream.WriteLine FormatDateTime(Now, 3) & " | MoveHere returned"
                End If
            End If
            Exit For
        End If
    End If
    On Error GoTo 0
Next

logStream.WriteLine FormatDateTime(Now, 3) & " | END"
logStream.Close

' Cleanup marker
On Error Resume Next
fso.DeleteFile markerFile, True
On Error GoTo 0
