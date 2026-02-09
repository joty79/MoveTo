' EditDestinations.vbs - Opens interactive editor

Set shell = CreateObject("Shell.Application")
args = "-ExecutionPolicy Bypass -NoExit -File ""D:\Users\joty79\scripts\MoveTo\EditDestinations.ps1"""
shell.ShellExecute "pwsh.exe", args, "", "", 1
