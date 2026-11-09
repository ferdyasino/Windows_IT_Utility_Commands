
@echo off
setlocal EnableExtensions
title System Hardware Inventory Generator

echo ============================================================
echo          SYSTEM HARDWARE INVENTORY GENERATOR
echo ============================================================
echo.

:: ------------------------------------------------------------
:: LOCATE WINDOWS POWERSHELL
:: ------------------------------------------------------------

set "PS_EXE="

if exist "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" (
    set "PS_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
)

if not defined PS_EXE (
    if exist "%SystemRoot%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe" (
        set "PS_EXE=%SystemRoot%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe"
    )
)

if not defined PS_EXE (
    echo ERROR: Windows PowerShell was not found.
    echo.
    echo Windows XP requires PowerShell 2.0 to be installed.
    echo.
    pause
    exit /b 1
)

:: ------------------------------------------------------------
:: EXTRACT EMBEDDED POWERSHELL SCRIPT
:: ------------------------------------------------------------

set "PSFILE=%TEMP%\SystemInventory_%RANDOM%_%RANDOM%.ps1"
set "PAYLOADLINE="

for /f "tokens=1 delims=:" %%N in ('findstr /n /b /c:"# POWERSHELL_PAYLOAD" "%~f0"') do (
    set "PAYLOADLINE=%%N"
)

if not defined PAYLOADLINE (
    echo ERROR: Cannot locate embedded PowerShell script.
    pause
    exit /b 1
)

more +%PAYLOADLINE% "%~f0" > "%PSFILE%"

if not exist "%PSFILE%" (
    echo ERROR: Could not create temporary PowerShell script.
    pause
    exit /b 1
)

echo Collecting system specifications and serial numbers...
echo.

"%PS_EXE%" -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File "%PSFILE%"

set "RESULT=%ERRORLEVEL%"

del "%PSFILE%" >nul 2>&1

echo.
if "%RESULT%"=="0" (
    echo ============================================
    echo REPORT GENERATION COMPLETED
    echo ============================================
) else (
    echo ============================================
    echo REPORT GENERATION FAILED
    echo Exit code: %RESULT%
    echo ============================================
)

echo.
pause
endlocal
exit /b

# POWERSHELL_PAYLOAD

# ============================================================
# SYSTEM HARDWARE INVENTORY
# Windows PowerShell 2.0 compatible
# Uses WMI instead of CIM
# ============================================================

$ErrorActionPreference = "Continue"

# ------------------------------------------------------------
# CHECK REQUIRED COMPONENTS
# ------------------------------------------------------------

try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
}
catch {
    Write-Host "ERROR: Windows Forms is unavailable." -ForegroundColor Red
    Write-Host "Check the installed .NET Framework." -ForegroundColor Yellow
    exit 1
}

# ------------------------------------------------------------
# HELPER FUNCTIONS
# ------------------------------------------------------------

function Get-WMIData {
    param(
        [string]$ClassName,
        [string]$Filter = ""
    )

    try {
        if ($Filter -ne "") {
            return @(Get-WmiObject -Class $ClassName -Filter $Filter -ErrorAction Stop)
        }
        else {
            return @(Get-WmiObject -Class $ClassName -ErrorAction Stop)
        }
    }
    catch {
        Write-Host ("WMI warning: {0} unavailable." -f $ClassName) -ForegroundColor Yellow
        return @()
    }
}

function Get-WMIFirst {
    param([string]$ClassName)

    $items = @(Get-WMIData $ClassName)

    if ($items.Count -gt 0) {
        return $items[0]
    }

    return $null
}

function Get-Value {
    param($InputValue)

    if ($null -eq $InputValue) {
        return "Not reported"
    }

    $value = [string]$InputValue

    if ($value.Trim() -eq "") {
        return "Not reported"
    }

    return $value
}

function New-Row {
    param($Properties)

    return New-Object PSObject -Property $Properties
}

function New-KV {
    param(
        [string]$Label,
        $InputValue
    )

    return New-Row @{
        Property = $Label
        Value = (Get-Value $InputValue)
    }
}

function Convert-WMIDate {
    param(
        $InputDate,
        $WMIObject
    )

    if ($null -eq $InputDate) {
        return "Not reported"
    }

    try {
        if ($null -ne $WMIObject) {
            return $WMIObject.ConvertToDateTime($InputDate).ToString("yyyy-MM-dd HH:mm:ss")
        }
    }
    catch {
    }

    return [string]$InputDate
}

function Make-Section {
    param(
        [string]$Title,
        $Data
    )

    $items = @($Data)

    if ($items.Count -eq 0) {
        $table = "<p>No information available.</p>"
    }
    else {
        $table = $items | ConvertTo-Html -Fragment | Out-String
    }

    return "<section><h2>$Title</h2>$table</section>"
}

# ------------------------------------------------------------
# SAVE AS DIALOG
# ------------------------------------------------------------

$dialog = New-Object System.Windows.Forms.SaveFileDialog

$dialog.Title = "Choose where to save System Inventory Report"
$dialog.Filter = "HTML Report (*.html)|*.html"
$dialog.DefaultExt = "html"
$dialog.AddExtension = $true
$dialog.OverwritePrompt = $true
$dialog.FileName = "System-Inventory-$env:COMPUTERNAME.html"

$desktop = [Environment]::GetFolderPath("Desktop")

if ($desktop -ne "" -and (Test-Path $desktop)) {
    $dialog.InitialDirectory = $desktop
}

if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
    Write-Host "Report generation cancelled." -ForegroundColor Yellow
    exit 0
}

$out = $dialog.FileName

Write-Host ""
Write-Host "Collecting hardware information..." -ForegroundColor Cyan

# ------------------------------------------------------------
# COMPUTER INFORMATION
# ------------------------------------------------------------

$cs = Get-WMIFirst "Win32_ComputerSystem"
$bios = Get-WMIFirst "Win32_BIOS"
$os = Get-WMIFirst "Win32_OperatingSystem"
$board = Get-WMIFirst "Win32_BaseBoard"
$product = Get-WMIFirst "Win32_ComputerSystemProduct"
$enclosure = Get-WMIFirst "Win32_SystemEnclosure"

# ------------------------------------------------------------
# HARDWARE COLLECTION
# ------------------------------------------------------------

$cpu = @(Get-WMIData "Win32_Processor")
$ram = @(Get-WMIData "Win32_PhysicalMemory")
$disks = @(Get-WMIData "Win32_DiskDrive")
$gpu = @(Get-WMIData "Win32_VideoController")
$net = @(Get-WMIData "Win32_NetworkAdapterConfiguration" "IPEnabled=True")
$battery = @(Get-WMIData "Win32_Battery")
$logicalDisks = @(Get-WMIData "Win32_LogicalDisk" "DriveType=3")

# ------------------------------------------------------------
# COMPUTER IDENTIFICATION
# ------------------------------------------------------------

$summary = @(
    (New-KV "Computer Name" $env:COMPUTERNAME)
    (New-KV "Manufacturer" $cs.Manufacturer)
    (New-KV "Model" $cs.Model)
    (New-KV "System Family" $cs.SystemFamily)
    (New-KV "System Serial Number" $bios.SerialNumber)
    (New-KV "System UUID" $product.UUID)
    (New-KV "Asset Tag" $enclosure.SMBIOSAssetTag)
    (New-KV "System Type" $cs.SystemType)
)

# ------------------------------------------------------------
# OPERATING SYSTEM
# ------------------------------------------------------------

$osdata = @(
    (New-KV "Operating System" $os.Caption)
    (New-KV "Version" $os.Version)
    (New-KV "Build Number" $os.BuildNumber)
    (New-KV "Architecture" $os.OSArchitecture)
    (New-KV "Windows Product ID" $os.SerialNumber)
    (New-KV "Install Date" (Convert-WMIDate $os.InstallDate $os))
    (New-KV "Last Boot" (Convert-WMIDate $os.LastBootUpTime $os))
    (New-KV "Service Pack" ($os.ServicePackMajorVersion))
)

# ------------------------------------------------------------
# PROCESSOR
# ------------------------------------------------------------

$cpudata = @()

foreach ($c in $cpu) {

    $cpudata += New-Row @{
        Processor = (Get-Value $c.Name)
        Manufacturer = (Get-Value $c.Manufacturer)
        ProcessorID = (Get-Value $c.ProcessorId)
        Cores = (Get-Value $c.NumberOfCores)
        LogicalProcessors = (Get-Value $c.NumberOfLogicalProcessors)
        MaxClockMHz = (Get-Value $c.MaxClockSpeed)
    }
}

# ------------------------------------------------------------
# MEMORY / RAM
# ------------------------------------------------------------

$ramTotalBytes = 0

foreach ($r in $ram) {
    if ($r.Capacity) {
        $ramTotalBytes += [double]$r.Capacity
    }
}

$ramTotalGB = [math]::Round(($ramTotalBytes / 1073741824), 2)

$ramdata = @()

$ramdata += New-Row @{
    Slot = "TOTAL INSTALLED"
    CapacityGB = $ramTotalGB
    Manufacturer = ""
    PartNumber = ""
    SerialNumber = ""
    SpeedMHz = ""
    ConfiguredSpeedMHz = ""
}

foreach ($r in $ram) {

    $capacity = "Not reported"

    if ($r.Capacity) {
        $capacity = [math]::Round(([double]$r.Capacity / 1073741824), 2)
    }

    $ramdata += New-Row @{
        Slot = (Get-Value $r.DeviceLocator)
        CapacityGB = $capacity
        Manufacturer = (Get-Value $r.Manufacturer)
        PartNumber = (Get-Value $r.PartNumber)
        SerialNumber = (Get-Value $r.SerialNumber)
        SpeedMHz = (Get-Value $r.Speed)
        ConfiguredSpeedMHz = (Get-Value $r.ConfiguredClockSpeed)
    }
}

# ------------------------------------------------------------
# STORAGE DEVICES
# Uses Win32_DiskDrive for XP through Windows 11
# ------------------------------------------------------------

$diskdata = @()
$physicaldata = @()

foreach ($d in $disks) {

    $capacity = "Not reported"

    if ($d.Size) {
        $capacity = [math]::Round(([double]$d.Size / 1073741824), 2)
    }

    $diskdata += New-Row @{
        Model = (Get-Value $d.Model)
        Manufacturer = (Get-Value $d.Manufacturer)
        SerialNumber = (Get-Value $d.SerialNumber)
        Firmware = (Get-Value $d.FirmwareRevision)
        CapacityGB = $capacity
        Interface = (Get-Value $d.InterfaceType)
        MediaType = (Get-Value $d.MediaType)
        PNPDeviceID = (Get-Value $d.PNPDeviceID)
    }

    $physicaldata += New-Row @{
        Model = (Get-Value $d.Model)
        SerialNumber = (Get-Value $d.SerialNumber)
        Status = (Get-Value $d.Status)
        StatusInfo = (Get-Value $d.StatusInfo)
        Availability = (Get-Value $d.Availability)
        Interface = (Get-Value $d.InterfaceType)
        Firmware = (Get-Value $d.FirmwareRevision)
    }
}

# ------------------------------------------------------------
# LOGICAL PARTITIONS
# ------------------------------------------------------------

$logicaldata = @()

foreach ($d in $logicalDisks) {

    $total = "Not reported"
    $free = "Not reported"

    if ($d.Size) {
        $total = [math]::Round(([double]$d.Size / 1073741824), 2)
    }

    if ($d.FreeSpace) {
        $free = [math]::Round(([double]$d.FreeSpace / 1073741824), 2)
    }

    $logicaldata += New-Row @{
        Drive = (Get-Value $d.DeviceID)
        VolumeName = (Get-Value $d.VolumeName)
        FileSystem = (Get-Value $d.FileSystem)
        TotalGB = $total
        FreeGB = $free
    }
}

# ------------------------------------------------------------
# MOTHERBOARD
# ------------------------------------------------------------

$boarddata = @(
    (New-KV "Manufacturer" $board.Manufacturer)
    (New-KV "Model / Product" $board.Product)
    (New-KV "Serial Number" $board.SerialNumber)
    (New-KV "Version" $board.Version)
)

# ------------------------------------------------------------
# BIOS
# ------------------------------------------------------------

$biosdata = @(
    (New-KV "BIOS Version" ($bios.SMBIOSBIOSVersion -join ", "))
    (New-KV "BIOS Serial Number" $bios.SerialNumber)
    (New-KV "BIOS Manufacturer" $bios.Manufacturer)
    (New-KV "BIOS Release Date" (Convert-WMIDate $bios.ReleaseDate $bios))
    (New-KV "SMBIOS Major Version" $bios.SMBIOSMajorVersion)
    (New-KV "SMBIOS Minor Version" $bios.SMBIOSMinorVersion)
)

# ------------------------------------------------------------
# GRAPHICS
# ------------------------------------------------------------

$gpudata = @()

foreach ($g in $gpu) {

    $videoRAM = "Not reported"

    if ($g.AdapterRAM -and [double]$g.AdapterRAM -gt 0) {
        $videoRAM = [math]::Round(([double]$g.AdapterRAM / 1073741824), 2)
    }

    $resolution = "Not reported"

    if ($g.CurrentHorizontalResolution -and $g.CurrentVerticalResolution) {
        $resolution = "$($g.CurrentHorizontalResolution) x $($g.CurrentVerticalResolution)"
    }

    $gpudata += New-Row @{
        GraphicsCard = (Get-Value $g.Name)
        DriverVersion = (Get-Value $g.DriverVersion)
        VideoRAMGB = $videoRAM
        Resolution = $resolution
    }
}

# ------------------------------------------------------------
# NETWORK / MAC ADDRESSES
# ------------------------------------------------------------

$netdata = @()

foreach ($n in $net) {

    $netdata += New-Row @{
        Adapter = (Get-Value $n.Description)
        MACAddress = (Get-Value $n.MACAddress)
        IPAddress = (Get-Value ($n.IPAddress -join ", "))
        Gateway = (Get-Value ($n.DefaultIPGateway -join ", "))
        DNS = (Get-Value ($n.DNSServerSearchOrder -join ", "))
    }
}

# ------------------------------------------------------------
# BATTERY
# ------------------------------------------------------------

$battdata = @()

foreach ($b in $battery) {

    $battdata += New-Row @{
        BatteryName = (Get-Value $b.Name)
        DeviceID = (Get-Value $b.DeviceID)
        Chemistry = (Get-Value $b.Chemistry)
        DesignCapacity = (Get-Value $b.DesignCapacity)
        EstimatedChargeRemaining = (Get-Value $b.EstimatedChargeRemaining)
    }
}

# ------------------------------------------------------------
# BUILD REPORT SECTIONS
# ------------------------------------------------------------

$sections = @()

$sections += Make-Section "COMPUTER IDENTIFICATION / SERIAL NUMBERS" $summary
$sections += Make-Section "OPERATING SYSTEM" $osdata
$sections += Make-Section "PROCESSOR / CPU" $cpudata
$sections += Make-Section "MEMORY / RAM MODULES" $ramdata
$sections += Make-Section "STORAGE DEVICES / SERIAL NUMBERS" $diskdata
$sections += Make-Section "DISK STATUS / DETAILS" $physicaldata
$sections += Make-Section "LOGICAL PARTITIONS" $logicaldata
$sections += Make-Section "MOTHERBOARD" $boarddata
$sections += Make-Section "BIOS DETAILS" $biosdata
$sections += Make-Section "GRAPHICS" $gpudata
$sections += Make-Section "NETWORK / MAC ADDRESSES" $netdata
$sections += Make-Section "BATTERY DETAILS" $battdata

# ------------------------------------------------------------
# HTML REPORT
# ------------------------------------------------------------

$reportDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$computerName = [System.Security.SecurityElement]::Escape([string]$env:COMPUTERNAME)

$html = @"
<!DOCTYPE html>
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<title>System Hardware Inventory</title>

<style type="text/css">

* {
    box-sizing: border-box;
}

body {
    font-family: Arial, Helvetica, sans-serif;
    background: #f1f4f8;
    color: #263445;
    margin: 0;
}

header {
    background: #17365d;
    color: #ffffff;
    padding: 25px 5%;
}

header h1 {
    margin: 0;
    font-size: 24px;
}

main {
    width: 100%;
    max-width: 1100px;
    margin: 25px auto;
    padding: 0 18px;
}

section {
    background: #ffffff;
    margin-bottom: 18px;
    padding: 20px;
    border: 1px solid #dddddd;
    max-width: 100%;
    overflow: hidden;
}

h2 {
    font-size: 17px;
    color: #17365d;
    border-bottom: 1px solid #dddddd;
    padding-bottom: 10px;
}

/* ------------------------------------------------------------
   TABLE LAYOUT AND TEXT WRAPPING
   ------------------------------------------------------------ */

table {
    width: 100%;
    max-width: 100%;
    border-collapse: collapse;
    table-layout: fixed;
}

th {
    background: #eaf0f7;
    text-align: left;
    font-weight: bold;
}

td,
th {
    padding: 9px;
    border: 1px solid #dddddd;
    text-align: left;
    vertical-align: top;

    /* Allow normal text wrapping */
    white-space: normal;

    /* Legacy browser support */
    word-wrap: break-word;

    /* Modern browser support */
    overflow-wrap: anywhere;

    /* Break long serial numbers and hardware identifiers */
    word-break: break-word;

    /* Keep cell contents within their boundaries */
    max-width: 100%;
}

/* Prevent long values from expanding the table */
td {
    overflow: hidden;
}

/* ------------------------------------------------------------
   ACTION BUTTON
   ------------------------------------------------------------ */

.actions {
    text-align: right;
    margin-bottom: 15px;
}

button {
    background: #2459a6;
    color: #ffffff;
    border: 0;
    padding: 11px 18px;
    cursor: pointer;
}

/* ------------------------------------------------------------
   FOOTER
   ------------------------------------------------------------ */

footer {
    text-align: center;
    padding: 20px;
    color: #777777;
}

/* ------------------------------------------------------------
   PRINT / SAVE AS PDF
   ------------------------------------------------------------ */

@media print {

    body {
        background: #ffffff;
    }

    header {
        background: #ffffff;
        color: #000000;
        border-bottom: 2px solid #333333;
    }

    .actions {
        display: none;
    }

    main {
        width: 100%;
        max-width: 100%;
        margin: 10px auto;
        padding: 0;
    }

    section {
        page-break-inside: auto;
        overflow: visible;
        border: 1px solid #dddddd;
    }

    table {
        width: 100%;
        max-width: 100%;
        table-layout: fixed;
    }

    td,
    th {
        white-space: normal;
        word-wrap: break-word;
        overflow-wrap: anywhere;
        word-break: break-word;
    }

    tr {
        page-break-inside: avoid;
    }

}

</style>
</head>

<body>

<header>
    <h1>System Hardware &amp; Software Inventory</h1>
    <p>Computer: $computerName | Generated: $reportDate</p>
</header>

<main>

<div class="actions">
    <button onclick="window.print()">Print / Save as PDF</button>
</div>

$($sections -join "`r`n")

<footer>
    Generated locally using Windows PowerShell and WMI
    <br>
    IT Asset Inventory
</footer>

</main>
</body>
</html>
"@

# ------------------------------------------------------------
# SAVE REPORT
# ------------------------------------------------------------

try {

    $html | Out-File -FilePath $out -Encoding UTF8 -ErrorAction Stop

    Write-Host ""
    Write-Host "============================================" -ForegroundColor Green
    Write-Host " REPORT GENERATED SUCCESSFULLY" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Saved to: $out" -ForegroundColor Cyan

    try {
        Start-Process $out
    }
    catch {
        Write-Host "Report saved, but automatic browser opening failed." -ForegroundColor Yellow
    }

}
catch {

    Write-Host ""
    Write-Host "ERROR SAVING REPORT:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

exit 0
