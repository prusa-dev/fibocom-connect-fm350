@echo off

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "cd '%~dp0%scripts'; & ./main.ps1"

if ERRORLEVEL 1 pause
