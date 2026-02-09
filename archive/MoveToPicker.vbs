Option Explicit

Dim basePath, destinationsPath, sourcePath
Dim fso, shellObj
Dim links, linkCount, menuText, answer, up, idx, shortcutPath, targetPath, i

If WScript.Arguments.Count = 0 Then WScript.Quit 1
sourcePath = WScript.Arguments(0)

Set fso = CreateObject("Scripting.FileSystemObject")
Set shellObj = CreateObject("WScript.Shell")

If Not fso.FileExists(sourcePath) And Not fso.FolderExists(sourcePath) Then WScript.Quit 1

basePath = "D:\Users\joty79\scripts\MoveTo"
destinationsPath = basePath & "\destinations"
If Not fso.FolderExists(destinationsPath) Then fso.CreateFolder destinationsPath

links = GetShortcutPathsSorted(destinationsPath)
linkCount = ArrayCount(links)
If linkCount = 0 Then
    MsgBox "No destinations found.", vbExclamation, "Move To"
    WScript.Quit 1
End If

menuText = "Move To - choose destination:" & vbCrLf & vbCrLf
For i = 0 To linkCount - 1
    menuText = menuText & (i + 1) & ". " & fso.GetBaseName(links(i)) & vbCrLf
Next
menuText = menuText & vbCrLf & "Q = Cancel"

answer = InputBox(menuText, "Move To")
If answer = "" Then WScript.Quit 0
up = UCase(Trim(answer))
If up = "Q" Then WScript.Quit 0
If Not IsNumeric(up) Then WScript.Quit 1

idx = CInt(up)
If idx < 1 Or idx > linkCount Then WScript.Quit 1

shortcutPath = links(idx - 1)
targetPath = ResolveShortcutTarget(shortcutPath)
If targetPath = "" Or Not fso.FolderExists(targetPath) Then
    MsgBox "Destination folder missing.", vbCritical, "Move To"
    WScript.Quit 1
End If

On Error Resume Next
If fso.FileExists(sourcePath) Then
    fso.MoveFile sourcePath, targetPath & "\"
ElseIf fso.FolderExists(sourcePath) Then
    fso.MoveFolder sourcePath, targetPath & "\"
Else
    MsgBox "Source missing.", vbCritical, "Move To"
    WScript.Quit 1
End If
If Err.Number <> 0 Then
    MsgBox "Move failed: " & Err.Description, vbCritical, "Move To"
    WScript.Quit 1
End If
On Error GoTo 0

Function ResolveShortcutTarget(shortcutFile)
    Dim lnk
    Set lnk = shellObj.CreateShortcut(shortcutFile)
    ResolveShortcutTarget = lnk.TargetPath
End Function

Function GetShortcutPathsSorted(folderPath)
    Dim folderObj, fileObj
    Dim names(), paths(), count
    Dim j, k, tName, tPath

    Set folderObj = fso.GetFolder(folderPath)
    count = 0

    For Each fileObj In folderObj.Files
        If LCase(fso.GetExtensionName(fileObj.Name)) = "lnk" Then
            ReDim Preserve names(count)
            ReDim Preserve paths(count)
            names(count) = LCase(fso.GetBaseName(fileObj.Name))
            paths(count) = fileObj.Path
            count = count + 1
        End If
    Next

    If count > 1 Then
        For j = 0 To count - 2
            For k = j + 1 To count - 1
                If names(k) < names(j) Then
                    tName = names(j)
                    names(j) = names(k)
                    names(k) = tName

                    tPath = paths(j)
                    paths(j) = paths(k)
                    paths(k) = tPath
                End If
            Next
        Next
    End If

    If count = 0 Then
        GetShortcutPathsSorted = Array()
    Else
        GetShortcutPathsSorted = paths
    End If
End Function

Function ArrayCount(arr)
    Dim n
    On Error Resume Next
    n = UBound(arr) - LBound(arr) + 1
    If Err.Number <> 0 Then
        Err.Clear
        n = 0
    End If
    On Error GoTo 0
    ArrayCount = n
End Function
