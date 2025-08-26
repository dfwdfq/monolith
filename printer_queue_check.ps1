#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Diagnoses and fixes printer queue dropout issues
.DESCRIPTION
    Comprehensive troubleshooting for when print jobs disappear from queue
    without printing, despite the printer being network accessible
#>

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

function Test-PrinterPort {
    param($PrinterName)
    
    $printer = Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue
    if (-not $printer) {
        Write-ColorOutput "Printer $PrinterName not found" "Red"
        return $false
    }
    
    $port = Get-PrinterPort -Name $printer.PortName -ErrorAction SilentlyContinue
    if (-not $port) {
        Write-ColorOutput "Port $($printer.PortName) not found" "Red"
        return $false
    }
    
    Write-ColorOutput "Testing connection to $($port.PrinterHostAddress)..." "Yellow"
    
    # Test basic connectivity
    $pingResult = Test-NetConnection -ComputerName $port.PrinterHostAddress -InformationLevel Quiet -WarningAction SilentlyContinue
    if (-not $pingResult) {
        Write-ColorOutput "✗ Cannot ping printer at $($port.PrinterHostAddress)" "Red"
        return $false
    }
    
    Write-ColorOutput "✓ Printer is pingable" "Green"
    
    # Test printer port (9100 is standard for raw printing)
    $portTest = Test-NetConnection -ComputerName $port.PrinterHostAddress -Port 9100 -InformationLevel Quiet -WarningAction SilentlyContinue
    if (-not $portTest) {
        Write-ColorOutput "✗ Printer port 9100 is not accessible" "Red"
        Write-ColorOutput "This could indicate a firewall issue or printer service problem" "Yellow"
        return $false
    }
    
    Write-ColorOutput "✓ Printer port 9100 is accessible" "Green"
    return $true
}

function Check-SpoolerService {
    Write-ColorOutput "`n[1] Checking Print Spooler service..." "Cyan"
    
    $service = Get-Service -Name Spooler -ErrorAction SilentlyContinue
    if (-not $service) {
        Write-ColorOutput "✗ Print Spooler service not found" "Red"
        return $false
    }
    
    Write-ColorOutput "Service status: $($service.Status)" $(if($service.Status -eq 'Running'){'Green'}else{'Red'})
    
    if ($service.Status -ne 'Running') {
        Write-ColorOutput "Attempting to start Print Spooler service..." "Yellow"
        try {
            Start-Service -Name Spooler -ErrorAction Stop
            Write-ColorOutput "✓ Print Spooler service started" "Green"
        } catch {
            Write-ColorOutput "✗ Failed to start Print Spooler: $($_.Exception.Message)" "Red"
            return $false
        }
    }
    
    # Check service dependencies
    $serviceInfo = Get-WmiObject -Class Win32_Service -Filter "Name='Spooler'"
    if ($serviceInfo.StartMode -ne 'Auto') {
        Write-ColorOutput "Warning: Print Spooler is not set to start automatically" "Yellow"
        Set-Service -Name Spooler -StartupType Automatic
        Write-ColorOutput "✓ Set Print Spooler to start automatically" "Green"
    }
    
    return $true
}

function Check-DriverIssues {
    param($PrinterName)
    
    Write-ColorOutput "`n[2] Checking printer driver issues..." "Cyan"
    
    $printer = Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue
    if (-not $printer) { return $false }
    
    # Check if driver is installed
    $driver = Get-PrinterDriver -Name $printer.DriverName -ErrorAction SilentlyContinue
    if (-not $driver) {
        Write-ColorOutput "✗ Printer driver '$($printer.DriverName)' not found" "Red"
        return $false
    }
    
    Write-ColorOutput "✓ Driver found: $($printer.DriverName)" "Green"
    
    # Check for driver conflicts
    $allDrivers = Get-PrinterDriver | Where-Object {$_.Name -like "*Pantum*"}
    if ($allDrivers.Count -gt 1) {
        Write-ColorOutput "Multiple Pantum drivers found. This can cause conflicts:" "Yellow"
        $allDrivers | Format-Table Name, Version -AutoSize
    }
    
    return $true
}

function Check-EventLogs {
    Write-ColorOutput "`n[3] Checking event logs for printer errors..." "Cyan"
    
    $printEvents = Get-WinEvent -FilterHashtable @{
        LogName = 'Application'
        ProviderName = 'Microsoft-Windows-PrintService'
        StartTime = (Get-Date).AddHours(-24)
    } -ErrorAction SilentlyContinue | Select-Object -First 10
    
    if ($printEvents) {
        Write-ColorOutput "Recent print service events:" "Yellow"
        foreach ($event in $printEvents) {
            $level = switch ($event.Level) {
                1 { "Critical"; break }
                2 { "Error"; break }
                3 { "Warning"; break }
                4 { "Information"; break }
                default { "Unknown" }
            }
            Write-ColorOutput "$($event.TimeCreated): [$level] $($event.Message)" $(if($level -eq "Error" -or $level -eq "Critical"){"Red"}else{"Yellow"})
        }
    } else {
        Write-ColorOutput "No recent print service events found" "Green"
    }
}

function Check-DiskSpace {
    Write-ColorOutput "`n[4] Checking system disk space..." "Cyan"
    
    $spoolDir = "$env:SYSTEMROOT\System32\spool"
    $drive = Get-PSDrive -Name $spoolDir.Substring(0, 1) -ErrorAction SilentlyContinue
    
    if ($drive) {
        $freePct = ($drive.Free / $drive.Used) * 100
        Write-ColorOutput "Spool directory: $spoolDir" "White"
        Write-ColorOutput "Free space: $([math]::Round($freePct, 2))%" $(if($freePct -lt 10){"Red"}else{"Green"})
        
        if ($freePct -lt 10) {
            Write-ColorOutput "✗ Low disk space may cause print job failures" "Red"
            return $false
        }
    }
    
    return $true
}

function Check-SpoolerDirectory {
    Write-ColorOutput "`n[5] Checking spooler directory permissions..." "Cyan"
    
    $spoolDir = "$env:SYSTEMROOT\System32\spool"
    
    try {
        $acl = Get-Acl -Path $spoolDir
        Write-ColorOutput "✓ Spool directory permissions are accessible" "Green"
        return $true
    } catch {
        Write-ColorOutput "✗ Cannot access spool directory permissions: $($_.Exception.Message)" "Red"
        return $false
    }
}

function Reset-Spooler {
    Write-ColorOutput "`n[6] Resetting print spooler..." "Cyan"
    
    try {
        Stop-Service -Name Spooler -Force -ErrorAction Stop
        Write-ColorOutput "✓ Print spooler stopped" "Green"
        
        # Clear spool directory
        Remove-Item -Path "$env:SYSTEMROOT\System32\spool\PRINTERS\*" -Force -ErrorAction SilentlyContinue
        Write-ColorOutput "✓ Print queue cleared" "Green"
        
        Start-Service -Name Spooler -ErrorAction Stop
        Write-ColorOutput "✓ Print spooler restarted" "Green"
        
        # Wait for service to stabilize
        Start-Sleep -Seconds 5
        return $true
    } catch {
        Write-ColorOutput "✗ Error resetting print spooler: $($_.Exception.Message)" "Red"
        return $false
    }
}

function Test-PrintJob {
    param($PrinterName)
    
    Write-ColorOutput "`n[7] Testing print job submission..." "Cyan"
    
    try {
        $testJob = "Test print job from troubleshooting script - $(Get-Date)"
        $job = $testJob | Out-Printer -Name $PrinterName -ErrorAction Stop
        
        Write-ColorOutput "✓ Test print job submitted successfully" "Green"
        
        # Monitor job for a few seconds
        Start-Sleep -Seconds 3
        $jobs = Get-PrintJob -PrinterName $PrinterName -ErrorAction SilentlyContinue
        
        if ($jobs) {
            Write-ColorOutput "Jobs in queue:" "Yellow"
            $jobs | Format-Table ID, Name, JobStatus -AutoSize
            return $true
        } else {
            Write-ColorOutput "Job disappeared from queue (typical of the reported issue)" "Red"
            return $false
        }
    } catch {
        Write-ColorOutput "✗ Failed to submit test print job: $($_.Exception.Message)" "Red"
        return $false
    }
}

function Get-AdvancedDiagnostics {
    param($PrinterName)
    
    Write-ColorOutput "`n[8] Running advanced diagnostics..." "Cyan"
    
    $printer = Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue
    if (-not $printer) { return }
    
    # Check for printer processor issues
    $processor = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Print\Environments\Windows x64\Print Processors" -ErrorAction SilentlyContinue
    if ($processor) {
        Write-ColorOutput "Print processor: $($processor."(default)")" "White"
    }
    
    # Check printer language monitor
    $monitors = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Print\Monitors" -ErrorAction SilentlyContinue
    if ($monitors) {
        Write-ColorOutput "Printer monitors installed:" "White"
        $monitors.PSChildName
    }
}

# Main execution
Clear-Host
Write-ColorOutput "==================================================" "Cyan"
Write-ColorOutput "   PRINTER QUEUE DROPOUT TROUBLESHOOTER" "Cyan"
Write-ColorOutput "==================================================" "Cyan"

# Get target printer
$printerName = Read-Host "`nEnter the name of the problematic printer"
if (-not (Get-Printer -Name $printerName -ErrorAction SilentlyContinue)) {
    Write-ColorOutput "Printer '$printerName' not found. Available printers:" "Red"
    Get-Printer | Format-Table Name, DriverName, PortName -AutoSize
    exit 1
}

Write-ColorOutput "`nStarting diagnostics for printer: $printerName" "Yellow"

# Run diagnostic sequence
$results = @{
    SpoolerService = Check-SpoolerService
    PrinterConnectivity = Test-PrinterPort -PrinterName $printerName
    DriverIssues = Check-DriverIssues -PrinterName $printerName
    DiskSpace = Check-DiskSpace
    SpoolerDirectory = Check-SpoolerDirectory
    EventLogs = $true  # Just displays, doesn't return success/fail
}

# Reset spooler if any checks failed
if ($results.Values -contains $false) {
    Write-ColorOutput "`nIssues detected. Attempting to reset print spooler..." "Yellow"
    $results.SpoolerReset = Reset-Spooler
}

# Test print job
$results.PrintTest = Test-PrintJob -PrinterName $printerName

# Advanced diagnostics
Get-AdvancedDiagnostics -PrinterName $printerName

# Summary
Write-ColorOutput "`n" "White"
Write-ColorOutput "==================================================" "Cyan"
Write-ColorOutput "   TROUBLESHOOTING SUMMARY" "Cyan"
Write-ColorOutput "==================================================" "Cyan"

foreach ($key in $results.Keys) {
    $status = if ($results[$key]) { "PASS" } else { "FAIL" }
    $color = if ($results[$key]) { "Green" } else { "Red" }
    Write-ColorOutput "$key : $status" $color
}

# Recommendations
Write-ColorOutput "`nRECOMMENDATIONS:" "Yellow"
if (-not $results.PrinterConnectivity) {
    Write-ColorOutput "• Check printer network settings and firewall" "White"
}
if (-not $results.DriverIssues) {
    Write-ColorOutput "• Reinstall printer driver from manufacturer website" "White"
    Write-ColorOutput "• Download from: https://www.pantum.com/support/download/" "White"
}
if (-not $results.DiskSpace) {
    Write-ColorOutput "• Free up disk space on system drive" "White"
}

Write-ColorOutput "`nTroubleshooting completed. Check recommendations above." "Green"