<#
.SYNOPSIS
Printer Job Manager - A CLI tool to manage print jobs for specific printers.

.DESCRIPTION
This script provides a command-line interface to view, pause, resume, and cancel print jobs
for a specified printer. It requires administrator privileges for some operations.

.PARAMETER PrinterName
The name of the printer to manage.

.PARAMETER Action
The action to perform: List, Pause, Resume, CancelAll, or CancelSingle.

.PARAMETER JobID
The ID of a specific print job to cancel (used with CancelSingle action).

.PARAMETER Help
Show detailed help information.

.EXAMPLE
.\PrinterJobManager.ps1 -PrinterName "My Pantum M6550NW" -Action List

.EXAMPLE
.\PrinterJobManager.ps1 -PrinterName "My Pantum M6550NW" -Action CancelAll

.EXAMPLE
.\PrinterJobManager.ps1 -PrinterName "My Pantum M6550NW" -Action CancelSingle -JobID 5

.EXAMPLE
.\PrinterJobManager.ps1 -Help
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$PrinterName,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("List", "Pause", "Resume", "CancelAll", "CancelSingle")]
    [string]$Action,
    
    [Parameter(Mandatory=$false)]
    [int]$JobID,
    
    [Parameter(Mandatory=$false)]
    [switch]$Help
)

# Function to display help information
function Show-Help {
    Write-Host "Printer Job Manager - Usage:" -ForegroundColor Yellow
    Write-Host "==========================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Basic Syntax:" -ForegroundColor Cyan
    Write-Host "  .\PrinterJobManager.ps1 -PrinterName `"Printer Name`" -Action <Action> [-JobID <ID>]" -ForegroundColor White
    Write-Host ""
    Write-Host "Available Actions:" -ForegroundColor Cyan
    Write-Host "  List         - View all print jobs for the printer" -ForegroundColor White
    Write-Host "  Pause        - Pause all printing for the printer" -ForegroundColor White
    Write-Host "  Resume       - Resume all printing for the printer" -ForegroundColor White
    Write-Host "  CancelAll    - Cancel all print jobs for the printer" -ForegroundColor White
    Write-Host "  CancelSingle - Cancel a specific print job (requires -JobID parameter)" -ForegroundColor White
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Cyan
    Write-Host "  .\PrinterJobManager.ps1 -PrinterName `"My Printer`" -Action List" -ForegroundColor White
    Write-Host "  .\PrinterJobManager.ps1 -PrinterName `"My Printer`" -Action Pause" -ForegroundColor White
    Write-Host "  .\PrinterJobManager.ps1 -PrinterName `"My Printer`" -Action CancelAll" -ForegroundColor White
    Write-Host "  .\PrinterJobManager.ps1 -PrinterName `"My Printer`" -Action CancelSingle -JobID 5" -ForegroundColor White
    Write-Host "  .\PrinterJobManager.ps1 -Help" -ForegroundColor White
    Write-Host ""
    Write-Host "Notes:" -ForegroundColor Cyan
    Write-Host "  - Some operations require Administrator privileges" -ForegroundColor White
    Write-Host "  - Use Get-Printer to see all available printers on your system" -ForegroundColor White
    Write-Host ""
}

# Function to list all available printers
function Show-Printers {
    Write-Host "Available printers on this system:" -ForegroundColor Cyan
    Write-Host "===================================" -ForegroundColor Cyan
    Get-Printer | Format-Table Name, DriverName, PortName, Shared -AutoSize
}

# Check if help was requested
if ($Help -or (-not $PrinterName -and -not $Action)) {
    Show-Help
    if (-not $PrinterName) {
        Show-Printers
    }
    exit 0
}

# Check if printer exists
function Test-PrinterExists {
    param([string]$Name)
    $printer = Get-Printer -Name $Name -ErrorAction SilentlyContinue
    return [bool]$printer
}

# Check if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $adminRole = [Security.Principal.WindowsBuiltInRole]::Administrator
    return (New-Object Security.Principal.WindowsPrincipal $currentUser).IsInRole($adminRole)
}

# Validate parameters
if (-not $PrinterName -or -not $Action) {
    Write-Host "Error: Both PrinterName and Action parameters are required." -ForegroundColor Red
    Show-Help
    exit 1
}

if ($Action -eq "CancelSingle" -and -not $JobID) {
    Write-Host "Error: JobID parameter is required for CancelSingle action." -ForegroundColor Red
    Show-Help
    exit 1
}

# Main script execution
Write-Host "Printer Job Manager" -ForegroundColor Green
Write-Host "===================" -ForegroundColor Green

# Validate printer exists
if (-not (Test-PrinterExists -Name $PrinterName)) {
    Write-Host "Error: Printer '$PrinterName' was not found." -ForegroundColor Red
    Show-Printers
    exit 1
}

# Check for administrator privileges for certain actions
if ($Action -in @("Pause", "Resume", "CancelAll", "CancelSingle") -and -not (Test-Administrator)) {
    Write-Host "Warning: Administrator privileges are required for this action." -ForegroundColor Yellow
    Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Yellow
    exit 1
}

# Execute the requested action
switch ($Action) {
    "List" {
        Write-Host "Listing print jobs for '$PrinterName':" -ForegroundColor Cyan
        $jobs = Get-PrintJob -PrinterName $PrinterName
        if ($jobs) {
            $jobs | Format-Table ID, DocumentName, SubmittedTime, Status, PagesPrinted, Size -AutoSize
        } else {
            Write-Host "No print jobs found for '$PrinterName'." -ForegroundColor Yellow
        }
    }
    
    "Pause" {
        Write-Host "Pausing all print jobs for '$PrinterName'..." -ForegroundColor Cyan
        Suspend-PrintJob -PrinterName $PrinterName
        Write-Host "Printing paused for '$PrinterName'." -ForegroundColor Green
    }
    
    "Resume" {
        Write-Host "Resuming all print jobs for '$PrinterName'..." -ForegroundColor Cyan
        Resume-PrintJob -PrinterName $PrinterName
        Write-Host "Printing resumed for '$PrinterName'." -ForegroundColor Green
    }
    
    "CancelAll" {
        Write-Host "Cancelling all print jobs for '$PrinterName'..." -ForegroundColor Cyan
        $jobs = Get-PrintJob -PrinterName $PrinterName
        if ($jobs) {
            $jobs | Remove-PrintJob
            Write-Host "All print jobs cancelled for '$PrinterName'." -ForegroundColor Green
        } else {
            Write-Host "No print jobs found to cancel for '$PrinterName'." -ForegroundColor Yellow
        }
    }
    
    "CancelSingle" {
        Write-Host "Cancelling print job $JobID for '$PrinterName'..." -ForegroundColor Cyan
        try {
            Remove-PrintJob -PrinterName $PrinterName -ID $JobID -ErrorAction Stop
            Write-Host "Print job $JobID cancelled for '$PrinterName'." -ForegroundColor Green
        } catch {
            Write-Host "Error: Could not find print job $JobID for '$PrinterName'." -ForegroundColor Red
            Write-Host "Available print jobs:" -ForegroundColor Yellow
            Get-PrintJob -PrinterName $PrinterName | Format-Table ID, DocumentName -AutoSize
        }
    }
    
    default {
        Write-Host "Error: Unknown action '$Action'." -ForegroundColor Red
        Show-Help
        exit 1
    }
}