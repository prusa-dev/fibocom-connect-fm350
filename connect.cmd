@echo off

:main
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "cd '%~dp0%scripts'; & ./main.ps1"
goto main

if ERRORLEVEL 1 pause
