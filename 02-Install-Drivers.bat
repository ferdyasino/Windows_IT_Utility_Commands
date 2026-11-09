
@echo off
setlocal EnableExtensions
title Windows Driver Installation Utility

echo ============================================================
echo               WINDOWS DRIVER INSTALLER
echo ============================================================
echo.

:: ------------------------------------------------------------
:: CHECK ADMINISTRATOR PRIVILEGES
:: ------------------------------------------------------------

net session >nul 2>&1

if not "%errorlevel%"=="0" (
    echo ERROR: Administrator privileges are required.
    echo Right-click this file and select Run as administrator.
    echo.
    pause
    exit /b 1
)

:: ------------------------------------------------------------
:: SELECT DRIVER SOURCE FOLDER
:: ------------------------------------------------------------

set "DRIVERDIR="
set "PICKER=%TEMP%\DriverInstallPicker_%RANDOM%.vbs"

(
    echo Set objShell = CreateObject^("Shell.Application"^)
    echo Set objFolder = objShell.BrowseForFolder^(0, "Select the folder containing your driver backup", 0, 0^)
    echo If Not objFolder Is Nothing Then
    echo     WScript.Echo objFolder.Self.Path
    echo End If
) > "%PICKER%"

echo Please select the folder containing your driver backup...
echo.

for /f "usebackq delims=" %%D in (`cscript //nologo "%PICKER%"`) do (
    set "DRIVERDIR=%%D"
)

del "%PICKER%" >nul 2>&1

if not defined DRIVERDIR (
    echo.
    echo No folder selected. Operation cancelled.
    pause
    exit /b 1
)

if not exist "%DRIVERDIR%\" (
    echo ERROR: Selected folder does not exist.
    echo.
    pause
    exit /b 1
)

:: ------------------------------------------------------------
:: CHECK PNPUTIL
:: ------------------------------------------------------------

set "PNPUTIL=%SystemRoot%\System32\pnputil.exe"

if not exist "%PNPUTIL%" (
    echo ERROR: PnPUtil was not found.
    echo.
    echo PnPUtil is included with Windows Vista and later.
    echo Windows XP requires a different driver installation method.
    echo.
    pause
    exit /b 1
)

:: ------------------------------------------------------------
:: DETECT WINDOWS BUILD
:: ------------------------------------------------------------

set "BUILD="

for /f "tokens=3" %%B in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CurrentBuildNumber 2^>nul') do (
    set "BUILD=%%B"
)

if not defined BUILD (
    for /f "tokens=4" %%B in ('ver') do set "BUILD=%%B"
)

if not defined BUILD (
    echo ERROR: Unable to detect Windows build.
    pause
    exit /b 1
)

echo ============================================================
echo INSTALLATION INFORMATION
echo ============================================================
echo Computer Name : %COMPUTERNAME%
echo Windows Build : %BUILD%
echo Driver Folder : "%DRIVERDIR%"
echo ============================================================
echo.

:: ------------------------------------------------------------
:: SEARCH FOR INF FILES
:: ------------------------------------------------------------

set "FOUND="
set "TOTAL=0"

echo Searching for driver INF files...
echo.

for /r "%DRIVERDIR%" %%F in (*.inf) do (
    set "FOUND=1"
    set /a TOTAL+=1
)

if not defined FOUND (
    echo No INF driver files were found.
    echo.
    echo Select the folder containing the exported driver packages.
    echo.
    pause
    exit /b 1
)

echo Driver INF files found: %TOTAL%
echo.

:: ------------------------------------------------------------
:: INITIALIZE COUNTERS
:: ------------------------------------------------------------

set "SUCCESS=0"
set "SKIPPED=0"
set "FAILED=0"
set "REBOOT=0"
set "PROCESSED=0"

echo Starting driver installation...
echo.

:: ------------------------------------------------------------
:: SELECT PNPUTIL INSTALLATION METHOD
:: ------------------------------------------------------------

if %BUILD% GEQ 14393 goto MODERN_INSTALL

goto LEGACY_INSTALL


:: ------------------------------------------------------------
:: MODERN PNPUTIL
:: WINDOWS 10 VERSION 1607 AND LATER
:: ------------------------------------------------------------

:MODERN_INSTALL

set "MODE=MODERN"

echo Using modern PnPUtil syntax...
echo.
echo Processing driver packages individually...
echo.

for /r "%DRIVERDIR%" %%F in (*.inf) do (
    call :INSTALL_INF "%%~fF"
)

goto INSTALL_SUMMARY


:: ------------------------------------------------------------
:: LEGACY PNPUTIL
:: VISTA / WINDOWS 7 / WINDOWS 8 / WINDOWS 8.1
:: ------------------------------------------------------------

:LEGACY_INSTALL

set "MODE=LEGACY"

echo Using legacy PnPUtil syntax...
echo.
echo Processing driver packages individually...
echo.

for /r "%DRIVERDIR%" %%F in (*.inf) do (
    call :INSTALL_INF "%%~fF"
)

goto INSTALL_SUMMARY


:: ------------------------------------------------------------
:: INSTALLATION SUMMARY
:: ------------------------------------------------------------

:INSTALL_SUMMARY

echo.
echo ============================================================
echo              DRIVER INSTALLATION SUMMARY
echo ============================================================
echo.
echo Computer Name       : %COMPUTERNAME%
echo Windows Build       : %BUILD%
echo Total INF Files     : %TOTAL%
echo Processed           : %PROCESSED%
echo Successfully Added  : %SUCCESS%
echo Skipped             : %SKIPPED%
echo Failed              : %FAILED%
echo.

if "%REBOOT%"=="1" (
    echo RESTART REQUIRED: Some driver installations require a restart.
)

if "%FAILED%"=="0" (
    echo ============================================================
    echo DRIVER PROCESSING COMPLETED WITHOUT REPORTED ERRORS
    echo ============================================================
) else (
    echo ============================================================
    echo SOME DRIVER PACKAGES REPORTED ERRORS
    echo ============================================================
    echo Review the installation output and SetupAPI log.
)

echo.
echo IMPORTANT:
echo.
echo 1. Some devices may require a Windows restart.
echo 2. This utility will not automatically restart Windows.
echo 3. Check Device Manager for devices with missing drivers.
echo 4. PnPUtil may not install a driver if a better-ranked
echo    driver is already installed.
echo.
echo ============================================================
pause
exit /b 0


:: ------------------------------------------------------------
:: INSTALL INDIVIDUAL INF FILE
:: ------------------------------------------------------------

:INSTALL_INF

set "INF=%~1"

echo ------------------------------------------------------------
echo Installing: %~nx1
echo ------------------------------------------------------------

if "%MODE%"=="MODERN" (
    "%PNPUTIL%" /add-driver "%INF%" /install
) else (
    "%PNPUTIL%" -i -a "%INF%"
)

set "RC=%ERRORLEVEL%"

set /a PROCESSED+=1

if "%RC%"=="0" goto INF_SUCCESS

if "%MODE%"=="MODERN" if "%RC%"=="259" goto INF_SKIPPED

if "%MODE%"=="MODERN" if "%RC%"=="3010" goto INF_REBOOT

if "%MODE%"=="MODERN" if "%RC%"=="1641" goto INF_REBOOT

goto INF_FAILED


:INF_SUCCESS

set /a SUCCESS+=1
echo [SUCCESS] Driver package processed.
echo.
exit /b 0


:INF_SKIPPED

set /a SKIPPED+=1
echo [SKIPPED] No matching device or a better driver is already installed.
echo.
exit /b 0


:INF_REBOOT

set /a SUCCESS+=1
set "REBOOT=1"
echo [SUCCESS] Driver package processed. Restart required.
echo.
exit /b 0


:INF_FAILED

set /a FAILED+=1
echo [ERROR] PnPUtil exit code: %RC%
echo.
exit /b 0
