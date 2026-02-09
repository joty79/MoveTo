@echo off
setlocal

set "BASE=D:\Users\joty79\scripts\MoveTo"

rem Cleanup old flat keys
reg delete "HKCU\Software\Classes\*\shell\MoveTo_Run" /f >nul 2>&1
reg delete "HKCU\Software\Classes\*\shell\MoveTo_Edit" /f >nul 2>&1
reg delete "HKCU\Software\Classes\*\shell\MoveTo_Test" /f >nul 2>&1
reg delete "HKCU\Software\Classes\Directory\shell\MoveTo_Run" /f >nul 2>&1
reg delete "HKCU\Software\Classes\Directory\shell\MoveTo_Add" /f >nul 2>&1
reg delete "HKCU\Software\Classes\Directory\shell\MoveTo_Edit" /f >nul 2>&1
reg delete "HKCU\Software\Classes\Directory\shell\MoveTo_Test" /f >nul 2>&1

rem Cleanup old cascade roots
reg delete "HKCU\Software\Classes\*\shell\MoveTo" /f >nul 2>&1
reg delete "HKCU\Software\Classes\Directory\shell\MoveTo" /f >nul 2>&1
reg delete "HKCU\Software\Classes\*\shell\MoveToCustom" /f >nul 2>&1
reg delete "HKCU\Software\Classes\Directory\shell\MoveToCustom" /f >nul 2>&1

if not exist "%BASE%\destinations" mkdir "%BASE%\destinations"

wscript.exe "%BASE%\SyncCascadeMenu.vbs"

taskkill /f /im explorer.exe >nul 2>&1
start explorer.exe

echo Move To cascade setup applied.
endlocal
