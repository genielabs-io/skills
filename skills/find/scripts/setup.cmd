@echo off
where pwsh.exe >nul 2>nul
if not errorlevel 1 goto pwsh
if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" goto standard_pwsh
where powershell.exe >nul 2>nul
if not errorlevel 1 goto windows_powershell
if exist "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" goto standard_windows_powershell
echo [ACTION] PowerShell 5.1 or later is required for local search.
echo Install instructions: https://learn.microsoft.com/powershell/scripting/install/install-powershell-on-windows
exit /b 2
:pwsh
pwsh.exe -NoProfile -File "%~dp0setup.ps1" %*
exit /b %errorlevel%
:windows_powershell
powershell.exe -NoProfile -File "%~dp0setup.ps1" %*
exit /b %errorlevel%
:standard_pwsh
"%ProgramFiles%\PowerShell\7\pwsh.exe" -NoProfile -File "%~dp0setup.ps1" %*
exit /b %errorlevel%
:standard_windows_powershell
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -File "%~dp0setup.ps1" %*
exit /b %errorlevel%
