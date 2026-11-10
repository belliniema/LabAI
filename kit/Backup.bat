@echo off
rem Doppio clic su Windows: Backup
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0lib\laboratorio.ps1" backup
