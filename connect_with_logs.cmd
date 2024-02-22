@echo off

:main
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "cd '%~dp0%scripts'; & ./main.ps1 -Verbose 4>../log-$((Get-Date).ToString('yyyyMMddhhmmss')).txt"
goto main

if ERRORLEVEL 1 pause
