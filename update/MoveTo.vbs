' MoveTo.vbs - Simple wrapper for MoveTo.ps1

Set objShell = CreateObject("WScript.Shell")

If WScript.Arguments.Count >= 2 Then
    sourcePath = WScript.Arguments(0)
    destName = WScript.Arguments(1)
    
    command = "pwsh.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File ""D:\Users\joty79\scripts\MoveTo\MoveTo.ps1"" """ & sourcePath & """ """ & destName & """"
    
    objShell.Run command, 0, False
End If
