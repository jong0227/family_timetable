@echo off
rem Design preview in a browser (localhost:5173). The real app targets Android.
cd /d "%~dp0.."
call C:\dev\flutter\bin\flutter.bat run -d web-server --web-port 5173 --web-hostname localhost
