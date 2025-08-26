<#
.SYNOPSIS
This script retrieves information about printers with "Pantum" in their name,
including detailed printer properties, associated drivers, and port information.
#>

Write-Host "Fetching printers with 'Pantum' in the name..." -ForegroundColor Green

# Get all printers with "Pantum" in the name
$printers = Get-Printer | Where-Object {$_.Name -like "*Pantum*"}

if ($printers.Count -eq 0) {
    Write-Host "No printers with 'Pantum' in the name were found." -ForegroundColor Yellow
    exit
}

Write-Host "Found $($printers.Count) printer(s) with 'Pantum' in the name:" -ForegroundColor Green
$printers | Format-Table Name, Type, DriverName, PortName -AutoSize

# Get detailed information for each Pantum printer
foreach ($printer in $printers) {
    Write-Host "`nDetailed information for printer: $($printer.Name)" -ForegroundColor Cyan
    Get-Printer -Name $printer.Name | Format-List *
}

# Check for Pantum printer drivers
Write-Host "`nChecking for Pantum printer drivers..." -ForegroundColor Green
$drivers = Get-PrinterDriver | Where-Object {$_.Name -like "*Pantum*"}

if ($drivers.Count -eq 0) {
    Write-Host "No Pantum printer drivers were found." -ForegroundColor Yellow
} else {
    Write-Host "Found $($drivers.Count) Pantum printer driver(s):" -ForegroundColor Green
    $drivers | Format-Table Name, DriverVersion, Manufacturer -AutoSize
}

# Get printer port information
Write-Host "`nChecking printer ports..." -ForegroundColor Green
Get-PrinterPort | Format-Table Name, Description, PrinterHostAddress, PortNumber -AutoSize

Write-Host "`nScript execution completed." -ForegroundColor Green