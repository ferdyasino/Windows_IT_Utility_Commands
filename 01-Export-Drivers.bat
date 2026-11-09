
@echo off
setlocal EnableExtensions
title Windows Driver Backup Utility

echo ============================================================
echo                 WINDOWS DRIVER BACKUP
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
:: DETECT WINDOWS BUILD
:: ------------------------------------------------------------

set "BUILD="

for /f "tokens=3" %%B in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CurrentBuildNumber 2^>nul') do (
    set "BUILD=%%B"
)

if not defined BUILD (
    for /f "tokens=4" %%B in ('ver') do set "BUILD=%%B"
)

echo Computer Name: %COMPUTERNAME%
echo Windows Build: %BUILD%
echo.

:: ------------------------------------------------------------
:: SELECT BACKUP LOCATION AND CREATE COMPUTER BACKUP FOLDER
:: ------------------------------------------------------------

set "DEST="
set "PICKER=%TEMP%\DriverFolderPicker_%RANDOM%.vbs"

(
    echo Set objShell = CreateObject^("Shell.Application"^)
    echo Set objFolder = objShell.BrowseForFolder^(0, "Select the main destination folder for driver backups", 0, 0^)
    echo If Not ^(objFolder Is Nothing^) Then
    echo     Set objNetwork = CreateObject^("WScript.Network"^)
    echo     Set objFSO = CreateObject^("Scripting.FileSystemObject"^)
    echo     computerName = objNetwork.ComputerName
    echo     stamp = CStr^(Year^(Now^)^) ^& Right^("0" ^& CStr^(Month^(Now^)^), 2^) ^& Right^("0" ^& CStr^(Day^(Now^)^), 2^) ^& "_" ^& Right^("0" ^& CStr^(Hour^(Now^)^), 2^) ^& Right^("0" ^& CStr^(Minute^(Now^)^), 2^) ^& Right^("0" ^& CStr^(Second^(Now^)^), 2^)
    echo     target = objFolder.Self.Path ^& "\" ^& computerName ^& "_DriverBackup_" ^& stamp
    echo     If Not objFSO.FolderExists^(target^) Then objFSO.CreateFolder^(target^)
    echo     WScript.Echo target
    echo End If
) > "%PICKER%"

echo Please select the main backup destination folder...

for /f "usebackq delims=" %%D in (`cscript //nologo "%PICKER%"`) do (
    set "DEST=%%D"
)

del "%PICKER%" >nul 2>&1

if not defined DEST (
    echo.
    echo No destination selected. Operation cancelled.
    pause
    exit /b 1
)

if not exist "%DEST%\" (
    echo.
    echo ERROR: Could not create the backup folder.
    echo Please check the destination drive and permissions.
    pause
    exit /b 1
)

echo.
echo ============================================================
echo BACKUP INFORMATION
echo ============================================================
echo Computer Name : %COMPUTERNAME%
echo Backup Folder : "%DEST%"
echo ============================================================
echo.

:: ------------------------------------------------------------
:: CREATE BACKUP INFORMATION FILE
:: ------------------------------------------------------------

(
    echo WINDOWS DRIVER BACKUP INFORMATION
    echo =================================
    echo Computer Name: %COMPUTERNAME%
    echo Windows Build: %BUILD%
    echo Backup Date: %DATE%
    echo Backup Time: %TIME%
    echo Backup Location: %DEST%
) > "%DEST%\Backup-Information.txt"

:: ------------------------------------------------------------
:: WINDOWS XP LIMITATION
:: ------------------------------------------------------------

if "%BUILD%"=="2600" (
    echo Windows XP detected.
    echo.
    echo Automatic driver-store export is not supported.
    echo Windows XP does not have the modern Windows DriverStore
    echo export mechanism used by this utility.
    echo.
    echo Please use the original hardware manufacturer's
    echo driver installers or a compatible third-party backup tool.
    echo.
    pause
    exit /b 1
)

:: ------------------------------------------------------------
:: WINDOWS 8.1 AND LATER - DISM EXPORT
:: Build 9600 = Windows 8.1
:: ------------------------------------------------------------

if %BUILD% GEQ 9600 goto DISM_EXPORT
goto LEGACY_EXPORT


:DISM_EXPORT

echo Using DISM to export third-party drivers...
echo.

dism /online /export-driver /destination:"%DEST%"

set "RESULT=%ERRORLEVEL%"

echo.

if "%RESULT%"=="0" (
    echo ============================================================
    echo DRIVER EXPORT COMPLETED SUCCESSFULLY
    echo ============================================================
    echo.
    echo Computer Name: %COMPUTERNAME%
    echo Backup Location:
    echo "%DEST%"
    echo.
    echo Backup information saved.
    echo.
    pause
    exit /b 0
)

echo ============================================================
echo DRIVER EXPORT FAILED
echo ============================================================
echo DISM Error Code: %RESULT%
echo.
echo Check the DISM error above.
echo.
pause
exit /b 1


:: ------------------------------------------------------------
:: WINDOWS VISTA / WINDOWS 7 / WINDOWS 8
:: RAW DRIVERSTORE BACKUP
:: ------------------------------------------------------------

:LEGACY_EXPORT

set "STORE=%SystemRoot%\System32\DriverStore\FileRepository"

if not exist "%STORE%" (
    echo ERROR: DriverStore FileRepository was not found.
    echo.
    echo This Windows version does not expose the expected
    echo driver-store folder.
    echo.
    pause
    exit /b 1
)

echo Older Windows version detected.
echo.
echo Copying DriverStore FileRepository...
echo This is a raw backup of stored driver files.
echo It is not a guaranteed DISM-style export.
echo.

if not exist "%DEST%\DriverStore\FileRepository" (
    mkdir "%DEST%\DriverStore\FileRepository"
)

xcopy "%STORE%\*" "%DEST%\DriverStore\FileRepository\" /E /I /H /K /Y

set "RESULT=%ERRORLEVEL%"

echo.

if "%RESULT%"=="0" (
    echo ============================================================
    echo DRIVERSTORE BACKUP COMPLETED
    echo ============================================================
    echo.
    echo Backup Location:
    echo "%DEST%\DriverStore\FileRepository"
    echo.
    echo Backup information saved.
    echo.
    pause
    exit /b 0
)

echo ============================================================
echo DRIVERSTORE BACKUP FAILED
echo ============================================================
echo Error Code: %RESULT%
echo.
pause
exit /b 1
