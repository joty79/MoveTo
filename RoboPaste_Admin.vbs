' Elevated wrapper for rcp.ps1 (Robo-Paste) using Windows Terminal
' MoveTo-local variant with dynamic script root.

Option Explicit

Dim objShell, fso, scriptRoot
Set objShell = CreateObject("Shell.Application")
Set fso = CreateObject("Scripting.FileSystemObject")
scriptRoot = fso.GetParentFolderName(WScript.ScriptFullName)

If WScript.Arguments.Count > 0 Then
    Dim folderPath, args
    folderPath = WScript.Arguments(0)
    args = "new-tab pwsh -NoProfile -ExecutionPolicy Bypass -File """ & scriptRoot & "\rcp.ps1"" auto auto """ & folderPath & """"
    objShell.ShellExecute "wt.exe", args, "", "runas", 1
End If

