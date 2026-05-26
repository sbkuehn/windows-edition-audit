<#
.SYNOPSIS
    Audits Windows edition across an environment to identify devices not running Windows 11 Enterprise.

.DESCRIPTION
    Queries Windows devices via CIM to return OS edition, version, and build number.
    Supports two input modes: a flat text file of computer names, or a live Active Directory query.
    Results are exported to CSV and displayed in the console.

    Companion script for the blog post:
    "The quiet licensing drift nobody notices until it matters"
    https://shankuehn.io

.PARAMETER Mode
    Required. Specifies the source of target computers.
    "List" reads from a text file. "AD" queries Active Directory.

.PARAMETER ComputerListPath
    Path to the text file containing computer names, one per line.
    Only used when Mode is "List". Defaults to .\computers.txt.

.PARAMETER ADNameFilter
    Wildcard filter applied to computer names when querying Active Directory.
    Only used when Mode is "AD". Defaults to "*" (all Windows computers).

.PARAMETER OutputPath
    Path for the exported CSV results file.
    Defaults to .\Windows11EnterpriseAudit.csv.

.EXAMPLE
    .\Get-WindowsEditionAudit.ps1 -Mode List -ComputerListPath .\computers.txt

.EXAMPLE
    .\Get-WindowsEditionAudit.ps1 -Mode AD

.EXAMPLE
    .\Get-WindowsEditionAudit.ps1 -Mode AD -ADNameFilter "VM-*"

.NOTES
    Author:  Shannon Eldridge-Kuehn
    Date:    2026-05-25
    Version: 1.0

    Requirements:
    - PowerShell 5.1 or later
    - WinRM enabled on target machines for remote CIM queries
    - ActiveDirectory module required when using -Mode AD
    - Appropriate permissions to query remote systems

    Unreachable machines are included in output with Reachable = $false
    so you have a complete picture of what was attempted vs. what responded.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("List", "AD")]
    [string]$Mode,

    [string]$ComputerListPath = ".\computers.txt",

    [string]$ADNameFilter = "*",

    [string]$OutputPath = ".\Windows11EnterpriseAudit.csv"
)

function Get-TargetComputers {
    param(
        [string]$Mode,
        [string]$ComputerListPath,
        [string]$ADNameFilter
    )

    if ($Mode -eq "List") {
        if (-not (Test-Path $ComputerListPath)) {
            throw "Computer list file not found: $ComputerListPath"
        }

        return Get-Content $ComputerListPath | Where-Object { $_ -and $_.Trim() -ne "" }
    }

    if ($Mode -eq "AD") {
        Import-Module ActiveDirectory -ErrorAction Stop

        return Get-ADComputer -Filter "Name -like '$ADNameFilter' -and OperatingSystem -like '*Windows*'" `
            -Properties OperatingSystem |
            Select-Object -ExpandProperty Name
    }
}

Write-Host "Windows Edition Audit" -ForegroundColor Cyan
Write-Host "Author: Shannon Eldridge-Kuehn | Date: 2026-05-25" -ForegroundColor DarkGray
Write-Host "Mode: $Mode`n" -ForegroundColor DarkGray

$computers = Get-TargetComputers -Mode $Mode -ComputerListPath $ComputerListPath -ADNameFilter $ADNameFilter

Write-Host "Found $($computers.Count) target computer(s). Querying..." -ForegroundColor Yellow

$results = foreach ($computer in $computers) {
    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ComputerName $computer -ErrorAction Stop

        [pscustomobject]@{
            ComputerName = $computer
            OSName       = $os.Caption
            Version      = $os.Version
            BuildNumber  = $os.BuildNumber
            SourceMode   = $Mode
            Reachable    = $true
        }
    }
    catch {
        Write-Warning "Could not reach $computer : $_"

        [pscustomobject]@{
            ComputerName = $computer
            OSName       = "Unreachable or access denied"
            Version      = $null
            BuildNumber  = $null
            SourceMode   = $Mode
            Reachable    = $false
        }
    }
}

$results | Sort-Object ComputerName | Export-Csv $OutputPath -NoTypeInformation

Write-Host "`nResults exported to: $OutputPath`n" -ForegroundColor Green

$results | Format-Table -AutoSize

$enterpriseCount = ($results | Where-Object { $_.OSName -like "*Enterprise*" }).Count
$totalReachable  = ($results | Where-Object { $_.Reachable -eq $true }).Count

Write-Host "Summary" -ForegroundColor Cyan
Write-Host "  Total targets:          $($computers.Count)"
Write-Host "  Reachable:              $totalReachable"
Write-Host "  Running Enterprise:     $enterpriseCount"
Write-Host "  Not Enterprise:         $($totalReachable - $enterpriseCount)" -ForegroundColor $(if (($totalReachable - $enterpriseCount) -gt 0) { "Yellow" } else { "Green" })
