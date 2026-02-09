' AddMoveToDestination.vbs - Silent wrapper (hidden window)

Set objShell = CreateObject("WScript.Shell")

If WScript.Arguments.Count > 0 Then
    folderPath = WScript.Arguments(0)
    args = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File ""D:\Users\joty79\scripts\MoveTo\AddMoveToDestination.ps1"" """ & folderPath & """"
    objShell.Run "pwsh.exe " & args, 0, False
End If
