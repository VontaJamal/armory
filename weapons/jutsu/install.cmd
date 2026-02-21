@echo off
REM jutsu installer — adds to your PATH for instant access

set "INSTALL_DIR=%USERPROFILE%\.openclaw\bin"
set "SCRIPT_DIR=%~dp0"

echo.
echo   Installing jutsu to %INSTALL_DIR%...
echo.

if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"

copy "%SCRIPT_DIR%jutsu.ps1" "%INSTALL_DIR%\jutsu.ps1" >nul

(
echo @echo off
echo powershell -ExecutionPolicy Bypass -File "%INSTALL_DIR%\jutsu.ps1" %%*
) > "%INSTALL_DIR%\armory-jutsu.cmd"

REM Add to user PATH if not already there
echo %PATH% | findstr /i /c:"%INSTALL_DIR%" >nul
if errorlevel 1 (
    for /f "tokens=2*" %%A in ('reg query "HKCU\Environment" /v PATH 2^>nul') do set "UPATH=%%B"
    if defined UPATH (
        setx PATH "%UPATH%;%INSTALL_DIR%" >nul
    ) else (
        setx PATH "%INSTALL_DIR%" >nul
    )
    echo   Added %INSTALL_DIR% to PATH
)

echo.
echo   Done. Open a new terminal and run: armory-jutsu
echo.
