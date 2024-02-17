@echo off

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "cd '%~dp0%scripts'; & ./main.ps1 -OnlyMonitor -Verbose 4>../log-$((Get-Date).ToString('yyyyMMddhhmmss')).txt"

if ERRORLEVEL 1 pause
