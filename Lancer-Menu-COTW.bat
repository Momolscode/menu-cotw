@echo off
rem Lance le Menu COTW (Windows). Double-cliquer sur ce fichier.
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0Menu-COTW.ps1"
if errorlevel 1 pause
