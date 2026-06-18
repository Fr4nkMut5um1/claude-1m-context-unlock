@echo off
REM ============================================================================
REM  Claude 1M Context Unlock - Windows entry point
REM  Just double-click this file. It launches the real installer (PowerShell).
REM  (Bilingual menu and docs are inside the PowerShell UI and README.md)
REM ============================================================================
setlocal
set "SCRIPT=%~dp0install-windows.ps1"

if not exist "%SCRIPT%" (
  echo [ERROR] install-windows.ps1 was not found next to this .bat file.
  echo         Make sure you extracted ALL files from the zip into one folder.
  echo.
  pause
  exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"

echo.
pause
