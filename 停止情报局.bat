@echo off
title Intel Bureau - stop workbench
cd /d "%~dp0"
if not exist "%~dp0scripts\stop.ps1" goto nofiles
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\stop.ps1" %*
set RC=%ERRORLEVEL%
echo.
pause
goto done
:nofiles
echo Cannot find scripts\stop.ps1 next to this file.
echo Please unzip the whole package first, do not run this from inside the zip.
pause
set RC=1
:done
exit /b %RC%