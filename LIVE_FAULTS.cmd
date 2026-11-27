@echo off
rem Live fault-only debug: dropped draws, pipeline errors, warnings.
rem Console + .temp\live-faults.log  (see scripts\live-faults.ps1)
setlocal
set "PS1=%~dp0scripts\live-faults.ps1"
set "PSH=powershell"
where pwsh >nul 2>nul && set "PSH=pwsh"
if not exist "%PS1%" (
  echo Not found: %PS1%
  pause
  exit /b 1
)
%PSH% -NoProfile -ExecutionPolicy Bypass -File "%PS1%" %*
echo.
pause
