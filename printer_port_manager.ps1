<#
.SYNOPSIS
Printer Port Manager - A CLI tool to manage printer ports and test connectivity.

.DESCRIPTION
This script provides a command-line interface to add, remove, and test printer ports.
It's useful for managing network printer connections.

.PARAMETER Action
The action to perform: AddPort, RemovePort, TestPort, or ListPorts.

.PARAMETER PortName
The name of the printer port to create or remove.

.PARAMETER PrinterHostAddress
The IP address or hostname of the printer (for AddPort and TestPort actions).

.PARAMETER PortNumber
The port number to test (default is 9100 for TestPort action).

.PARAMETER Help
Show detailed help information.

.EXAMPLE
.\PrinterPortManager.ps1 -Action AddPort -PortName "Pantum_Port" -PrinterHostAddress "192.168.3.100"

.EXAMPLE
.\PrinterPortManager.ps1 -Action RemovePort -PortName "Pantum_Port"

.EXAMPLE
.\PrinterPortManager.ps1 -Action TestPort -PrinterHostAddress "192.168.3.100"

.EXAMPLE
.\PrinterPortManager.ps1 -Action ListPorts

.EXAMPLE
.\PrinterPortManager.ps1 -Help
#>

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("AddPort", "RemovePort", "TestPort", "ListPorts")]
    [string]$Action,
    
    [Parameter(Mandatory=$false)]
    [string]$PortName,
    
    [Parameter(Mandatory=$false)]
    [string]$PrinterHostAddress,
    
    [Parameter(Mandatory=$false)]
    [int]$PortNumber = 9100,
    
    [Parameter(Mandatory=$false)]
    [switch]$Help
)

# Function to display help information
function Show-Help {
    Write-Host "Printer Port Manager - Usage:" -ForegroundColor Yellow
    Write-Host "==========================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Available Actions:" -ForegroundColor Cyan
    Write-Host "  AddPort     - Add a new printer port" -ForegroundColor White
    Write-Host "  RemovePort  - Remove an existing printer port" -ForegroundColor White
    Write-Host "  TestPort    - Test connectivity to a printer port" -ForegroundColor White
    Write-Host "  ListPorts   - List all available printer ports" -ForegroundColor White
    Write-Host ""
    Write-Host "Parameters:" -ForegroundColor Cyan
    Write-Host "  -Action <Action>           - The action to perform (required)" -ForegroundColor White
    Write-Host "  -PortName <Name>           - Name of the port (required for AddPort/RemovePort)" -ForegroundColor White
    Write-Host "  -PrinterHostAddress <IP>   - IP address of the printer (required for AddPort/TestPort)" -ForegroundColor White
    Write-Host "  -PortNumber <Number>       - Port number to test (optional, default: 9100)" -ForegroundColor White
    Write-Host "  -Help                      - Show this help message" -ForegroundColor White
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Cyan
    Write-Host "  .\PrinterPortManager.ps1 -Action AddPort -PortName `"Pantum_Port`" -PrinterHostAddress `"192.168.3.100`"" -ForegroundColor White
    Write-Host "  .\PrinterPortManager.ps1 -Action RemovePort -PortName `"Pantum_Port`"" -ForegroundColor White
    Write-Host "  .\PrinterPortManager.ps1 -Action TestPort -PrinterHostAddress `"192.168.3.100`"" -ForegroundColor White
    Write-Host "  .\PrinterPortManager.ps1 -Action TestPort -PrinterHostAddress `"192.168.3.100`" -PortNumber 9100" -ForegroundColor White
    Write-Host "  .\PrinterPortManager.ps1 -Action ListPorts" -ForegroundColor White
    Write-Host "  .\PrinterPortManager.ps1 -Help" -ForegroundColor White
    Write-Host ""
    Write-Host "Notes:" -ForegroundColor Cyan
    Write-Host "  - Administrator privileges are required for AddPort and RemovePort actions" -ForegroundColor White
    Write-Host "  - Standard TCP/IP printer ports typically use port 9100" -ForegroundColor White
}

# Check if help was requested or no action specified
if ($Help -or (-not $Action)) {
    Show-Help
    exit 0
}

# Check if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $adminRole = [Security.Principal.WindowsBuiltInRole]::Administrator
    return (New-Object Security.Principal.WindowsPrincipal $currentUser).IsInRole($adminRole)
}

# Validate parameters based on action
switch ($Action) {
    "AddPort" {
        if (-not $PortName -or -not $PrinterHostAddress) {
            Write-Host "Error: Both PortName and PrinterHostAddress are required for AddPort action." -ForegroundColor Red
            Show-Help
            exit 1
        }
        
        if (-not (Test-Administrator)) {
            Write-Host "Warning: Administrator privileges are required to add printer ports." -ForegroundColor Yellow
            Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Yellow
            exit 1
        }
    }
    
    "RemovePort" {
        if (-not $PortName) {
            Write-Host "Error: PortName is required for RemovePort action." -ForegroundColor Red
            Show-Help
            exit 1
        }
        
        if (-not (Test-Administrator)) {
            Write-Host "Warning: Administrator privileges are required to remove printer ports." -ForegroundColor Yellow
            Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Yellow
            exit 1
        }
    }
    
    "TestPort" {
        if (-not $PrinterHostAddress) {
            Write-Host "Error: PrinterHostAddress is required for TestPort action." -ForegroundColor Red
            Show-Help
            exit 1
        }
    }
}

# Main script execution
Write-Host "Printer Port Manager" -ForegroundColor Green
Write-Host "====================" -ForegroundColor Green

# Execute the requested action
switch ($Action) {
    "AddPort" {
        Write-Host "Adding printer port '$PortName' for $PrinterHostAddress..." -ForegroundColor Cyan
        try {
            Add-PrinterPort -Name $PortName -PrinterHostAddress $PrinterHostAddress -ErrorAction Stop
            Write-Host "Successfully added printer port: $PortName" -ForegroundColor Green
        } catch {
            Write-Host "Error: Failed to add printer port. $($_.Exception.Message)" -ForegroundColor Red
            exit 1
        }
    }
    
    "RemovePort" {
        Write-Host "Removing printer port '$PortName'..." -ForegroundColor Cyan
        try {
            Remove-PrinterPort -Name $PortName -ErrorAction Stop
            Write-Host "Successfully removed printer port: $PortName" -ForegroundColor Green
        } catch {
            Write-Host "Error: Failed to remove printer port. $($_.Exception.Message)" -ForegroundColor Red
            exit 1
        }
    }
    
    "TestPort" {
        Write-Host "Testing connectivity to $PrinterHostAddress on port $PortNumber..." -ForegroundColor Cyan
        try {
            $result = Test-NetConnection -ComputerName $PrinterHostAddress -Port $PortNumber -InformationLevel Quiet -ErrorAction Stop
            if ($result) {
                Write-Host "Success: Connection to $PrinterHostAddress on port $PortNumber is working." -ForegroundColor Green
            } else {
                Write-Host "Failed: Cannot connect to $PrinterHostAddress on port $PortNumber." -ForegroundColor Red
            }
        } catch {
            Write-Host "Error: Failed to test connection. $($_.Exception.Message)" -ForegroundColor Red
            exit 1
        }
    }
    
    "ListPorts" {
        Write-Host "Listing all printer ports:" -ForegroundColor Cyan
        try {
            $ports = Get-PrinterPort
            if ($ports) {
                $ports | Format-Table Name, Description, PrinterHostAddress, PortNumber -AutoSize
            } else {
                Write-Host "No printer ports found." -ForegroundColor Yellow
            }
        } catch {
            Write-Host "Error: Failed to retrieve printer ports. $($_.Exception.Message)" -ForegroundColor Red
            exit 1
        }
    }
    
    default {
        Write-Host "Error: Unknown action '$Action'." -ForegroundColor Red
        Show-Help
        exit 1
    }
}