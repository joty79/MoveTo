Option Explicit

Dim basePath, destinationsPath
Dim rootFile, rootDir

basePath = "D:\Users\joty79\scripts\MoveTo"
destinationsPath = basePath & "\destinations"
rootFile = "HKCU\Software\Classes\*\shell\MoveToCustom"
rootDir = "HKCU\Software\Classes\Directory\shell\MoveToCustom"

EnsureFolder destinationsPath

BuildRoot rootFile, False
BuildRoot rootDir, True

Sub BuildRoot(rootKey, allowAdd)
    Dim i, itemKey, nameText, linkPath, iconText, cmdText
    Dim links, linkCount

    RegDeleteTree rootKey

    RegAdd rootKey, "", "Move To"
    RegAdd rootKey, "MUIVerb", "Move To"
    RegAdd rootKey, "SubCommands", ""
    RegAdd rootKey, "Icon", "shell32.dll,-16761"
    RegAdd rootKey & "\shell", "", ""

    links = GetShortcutPathsSorted(destinationsPath)
    linkCount = ArrayCount(links)

    For i = 0 To linkCount - 1
        linkPath = links(i)
        nameText = GetBaseName(linkPath)
        iconText = ResolveShortcutIcon(linkPath)
        itemKey = rootKey & "\shell\" & Right("000" & CStr(100 + i), 3) & "_" & SanitizeKey(nameText)
        cmdText = "wscript.exe """ & basePath & "\MoveToExec.vbs"" ""%1"" """ & linkPath & """"

        RegAdd itemKey, "", nameText
        RegAdd itemKey, "MUIVerb", nameText
        RegAdd itemKey, "Icon", iconText
        RegAdd itemKey & "\command", "", cmdText
    Next

    If allowAdd Then
        RegAdd rootKey & "\shell\900_AddDestination", "", "Add as destination"
        RegAdd rootKey & "\shell\900_AddDestination", "MUIVerb", "Add as destination"
        RegAdd rootKey & "\shell\900_AddDestination", "Icon", "shell32.dll,-16769"
        RegAdd rootKey & "\shell\900_AddDestination\command", "", "wscript.exe """ & basePath & "\AddMoveToDestination.vbs"" ""%1"""
    End If

    RegAdd rootKey & "\shell\910_EditDestinations", "", "Edit destinations"
    RegAdd rootKey & "\shell\910_EditDestinations", "MUIVerb", "Edit destinations"
    RegAdd rootKey & "\shell\910_EditDestinations", "Icon", "shell32.dll,-16710"
    RegAdd rootKey & "\shell\910_EditDestinations\command", "", "wscript.exe """ & basePath & "\EditDestinations.vbs"""
End Sub

Sub EnsureFolder(folderPath)
    Dim fso
    Set fso = CreateObject("Scripting.FileSystemObject")
    If Not fso.FolderExists(folderPath) Then fso.CreateFolder folderPath
End Sub

Sub RegAdd(keyPath, valueName, valueData)
    Dim sh, fullPath
    Set sh = CreateObject("WScript.Shell")

    If valueName = "" Then
        fullPath = keyPath & "\"
    Else
        fullPath = keyPath & "\" & valueName
    End If

    sh.RegWrite fullPath, valueData, "REG_SZ"
End Sub

Sub RegDeleteTree(keyPath)
    Dim sh
    Set sh = CreateObject("WScript.Shell")
    sh.Run "cmd /c reg delete """ & keyPath & """ /f", 0, True
End Sub

Function GetBaseName(pathValue)
    Dim fso
    Set fso = CreateObject("Scripting.FileSystemObject")
    GetBaseName = fso.GetBaseName(pathValue)
End Function

Function ResolveShortcutIcon(shortcutPath)
    Dim sh, lnk, iconText
    Set sh = CreateObject("WScript.Shell")
    Set lnk = sh.CreateShortcut(shortcutPath)
    iconText = lnk.IconLocation
    If iconText = "" Then
        ResolveShortcutIcon = "shell32.dll,-3"
    Else
        ResolveShortcutIcon = iconText
    End If
End Function

Function SanitizeKey(textValue)
    Dim i, ch, outText
    outText = ""
    For i = 1 To Len(textValue)
        ch = Mid(textValue, i, 1)
        If (ch >= "a" And ch <= "z") Or (ch >= "A" And ch <= "Z") Or (ch >= "0" And ch <= "9") Then
            outText = outText & ch
        Else
            outText = outText & "_"
        End If
    Next
    If outText = "" Then outText = "Destination"
    SanitizeKey = outText
End Function

Function GetShortcutPathsSorted(folderPath)
    Dim fso, folderObj, fileObj
    Dim names(), paths(), count
    Dim i, j, tName, tPath

    Set fso = CreateObject("Scripting.FileSystemObject")
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
        For i = 0 To count - 2
            For j = i + 1 To count - 1
                If names(j) < names(i) Then
                    tName = names(i)
                    names(i) = names(j)
                    names(j) = tName

                    tPath = paths(i)
                    paths(i) = paths(j)
                    paths(j) = tPath
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
