# Windows Driver & IT Administration Toolkit

A collection of simple Windows utilities designed to help IT technicians and support personnel manage computer drivers and hardware information.

## Available Utilities

### 1. Windows Driver Backup

**File:** `Export-Windows-Drivers.bat`

**What it does:**
Creates a backup of the computer's available driver packages.

**How to use:**

1. Run the BAT file as Administrator.
2. Select the folder where you want to save the backup.
3. Wait for the backup process to finish.
4. Keep the backup folder for future driver installation.

### 2. Windows Driver Installation

**File:** `Install-Windows-Drivers.bat`

**What it does:**
Installs drivers from a previously created backup or another folder containing driver packages.

**How to use:**

1. Run the BAT file as Administrator.
2. Select the folder containing the drivers when prompted.
3. Wait for the installation process to finish.
4. Review the results.
5. Restart the computer if required.
6. Check Device Manager to verify the drivers.

### 3. System Information & Hardware Inventory

**File:** `System-Information-Hardware-Inventory.bat`

**What it does:**
Collects important computer specifications and generates an HTML inventory report.

**Information collected includes:**

- Computer name, manufacturer, and model
- Computer serial number and asset tag (when available)
- Windows version and system information
- Processor specifications
- Installed RAM and memory details
- Hard drive and storage information
- Motherboard and BIOS information
- Graphics card information
- Network adapters, IP addresses, and MAC addresses
- Battery information (when available)

**How to use:**

1. Run the BAT file.
2. Wait while the computer information is collected.
3. Choose where to save the inventory report.
4. Save the generated HTML file.
5. Open the report in a web browser.
6. Use **Print / Save as PDF** if you need a PDF copy.

---

## Important Reminders

- Run the driver utilities as Administrator.
- Close other applications before installing drivers when possible.
- Always use drivers compatible with the computer and Windows version.
- Some driver installations may require a restart.
- Keep driver backups in a safe location.
- Some hardware information may not be available depending on the computer.
- The hardware inventory utility requires Windows PowerShell and Windows Forms support.

## Project Structure

```text
windows-driver-toolkit/
│
├── scripts/
│   ├── Export-Windows-Drivers.bat
│   ├── Install-Windows-Drivers.bat
│   └── System-Information-Hardware-Inventory.bat
│
├── README.md
├── README.txt
└── .gitignore
```

## Author

**Ferdinand Asino**

GitHub: https://github.com/ferdyasino

**Windows Driver & IT Administration Toolkit**
