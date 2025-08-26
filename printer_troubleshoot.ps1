#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Pantum Printer Troubleshooter for Windows 11
.DESCRIPTION
    This script diagnoses and fixes common issues with Pantum printers on Windows 11
.NOTES
    Version: 1.0
    Author: Your Name
    Date: $(Get-Date -Format "yyyy-MM-dd")
#>

# Clear the screen
Clear-Host

Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "    Pantum Printer Troubleshooter for Windows 11" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check if we're running on Windows 11
$osInfo = Get-ComputerInfo
if ($osInfo.WindowsVersion -notlike "11*") {
    Write-Warning "This script is designed for Windows 11. You're running $($osInfo.WindowsVersion)"
    $continue = Read-Host "Continue anyway? (y/n)"
    if ($continue -ne 'y') { exit }
}

# Step 2: Find Pantum printers
Write-Host "`n[1/6] Searching for Pantum printers..." -ForegroundColor Yellow
$pantumPrinters = Get-Printer | Where-Object {$_.Name -like "*Pantum*" -or $_.DriverName -like "*Pantum*"}

if (-not $pantumPrinters) {
    Write-Host "No Pantum printers found." -ForegroundColor Red
    Write-Host "Please make sure your printer is connected and powered on." -ForegroundColor Yellow
    exit 1
}

Write-Host "Found $($pantumPrinters.Count) Pantum printer(s):" -ForegroundColor Green
$pantumPrinters | Format-Table Name, DriverName, PortName -AutoSize

# Step 3: Check printer status
Write-Host "`n[2/6] Checking printer status..." -ForegroundColor Yellow
foreach ($printer in $pantumPrinters) {
    Write-Host "Printer: $($printer.Name) - Status: $($printer.PrinterStatus)" -ForegroundColor $(if($printer.PrinterStatus -eq 'Normal'){'Green'}else{'Red'})
    
    # Check for pending print jobs
    $jobs = Get-PrintJob -PrinterName $printer.Name
    if ($jobs) {
        Write-Host "Pending jobs found: $($jobs.Count)" -ForegroundColor Red
        $jobs | Format-Table ID, Name, JobStatus -AutoSize
    }
}

# Step 4: Restart print spooler and clear queue
Write-Host "`n[3/6] Restarting print spooler and clearing queue..." -ForegroundColor Yellow
try {
    Stop-Service -Name Spooler -Force -ErrorAction Stop
    Write-Host "Print spooler stopped" -ForegroundColor Green
    
    # Clear print queue
    Remove-Item -Path "$env:SYSTEMROOT\System32\spool\PRINTERS\*" -Force -ErrorAction SilentlyContinue
    Write-Host "Print queue cleared" -ForegroundColor Green
    
    Start-Service -Name Spooler -ErrorAction Stop
    Write-Host "Print spooler restarted" -ForegroundColor Green
    
    # Wait for service to fully start
    Start-Sleep -Seconds 3
}
catch {
    Write-Host "Error managing print spooler: $($_.Exception.Message)" -ForegroundColor Red
}

# Step 5: Check network connectivity
Write-Host "`n[4/6] Checking network connectivity..." -ForegroundColor Yellow
foreach ($printer in $pantumPrinters) {
    $port = Get-PrinterPort -Name $printer.PortName -ErrorAction SilentlyContinue
    if ($port -and $port.PrinterHostAddress) {
        Write-Host "Testing connection to $($port.PrinterHostAddress)..." -ForegroundColor Yellow
        
        # Test connectivity
        $pingResult = Test-NetConnection -ComputerName $port.PrinterHostAddress -InformationLevel Quiet -WarningAction SilentlyContinue
        if ($pingResult) {
            Write-Host "✓ Printer is reachable at $($port.PrinterHostAddress)" -ForegroundColor Green
            
            # Test printer port
            $portTest = Test-NetConnection -ComputerName $port.PrinterHostAddress -Port 9100 -InformationLevel Quiet -WarningAction SilentlyContinue
            if ($portTest) {
                Write-Host "✓ Printer port 9100 is accessible" -ForegroundColor Green
            } else {
                Write-Host "✗ Printer port 9100 is not accessible" -ForegroundColor Red
            }
        } else {
            Write-Host "✗ Printer is not reachable at $($port.PrinterHostAddress)" -ForegroundColor Red
            Write-Host "Please check:" -ForegroundColor Yellow
            Write-Host "  - Printer is powered on and connected to Wi-Fi" -ForegroundColor Yellow
            Write-Host "  - Printer and computer are on the same network" -ForegroundColor Yellow
            Write-Host "  - IP address is correct" -ForegroundColor Yellow
        }
    }
}

# Step 6: Print test page
Write-Host "`n[5/6] Attempting to print test page..." -ForegroundColor Yellow
foreach ($printer in $pantumPrinters) {
    try {
        # Create a simple test document
        $testContent = @"
=================================
      Pantum Printer Test
=================================
Printer: $($printer.Name)
Time: $(Get-Date)
Status: $($printer.PrinterStatus)
=================================
This is a test page from the
Pantum Troubleshooter script.
If you can read this, your
printer is working correctly!
=================================
"@
        
        # Print the test content
        $testContent | Out-Printer -Name $printer.Name
        Write-Host "✓ Test page sent to $($printer.Name)" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ Failed to send test page to $($printer.Name): $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Step 7: Final recommendations
Write-Host "`n[6/6] Final recommendations:" -ForegroundColor Yellow

if ($pantumPrinters.PrinterStatus -contains 'Error') {
    Write-Host "• One or more printers are in error state" -ForegroundColor Red
    Write-Host "• Consider reinstalling the printer driver" -ForegroundColor Yellow
}

Write-Host "• Download latest drivers from: https://www.pantum.com/support/download/" -ForegroundColor Cyan
Write-Host "• Ensure printer firmware is up to date" -ForegroundColor Cyan
Write-Host "• For wireless printers, check Wi-Fi connection on the printer itself" -ForegroundColor Cyan

Write-Host "`nTroubleshooting completed!" -ForegroundColor Green

# Optional: Offer to open printer settings
$openSettings = Read-Host "`nOpen Windows printer settings? (y/n)"
if ($openSettings -eq 'y') {
    Start-Process "ms-settings:printers"
}