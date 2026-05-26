# Windows Edition Audit

**Author:** Shannon Eldridge-Kuehn  
**Date:** 2026-05-25  
**Blog:** [shankuehn.io](https://shankuehn.io)

Companion script for the post: *The quiet licensing drift nobody notices until it matters*

---

## What this does

Windows 11 Enterprise is no longer something you install once and confirm once. It is a state that depends on user licensing, device join, and management alignment, and those conditions can drift apart quietly over time.

This script queries your Windows devices via CIM to return the OS edition, version, and build number for each machine. It supports two input modes so it fits however your environment is set up: a flat text file of computer names, or a live query against Active Directory. Results are written to CSV and summarized in the console so you immediately see where Enterprise is and is not showing up.

---

## Requirements

- PowerShell 5.1 or later
- WinRM enabled on target machines
- Appropriate read permissions to query remote systems
- `ActiveDirectory` PowerShell module (only required when using `-Mode AD`)

---

## Parameters

| Parameter | Required | Default | Description |
|---|---|---|---|
| `-Mode` | Yes | | `List` to use a text file, `AD` to query Active Directory |
| `-ComputerListPath` | No | `.\computers.txt` | Path to your computer name list (List mode only) |
| `-ADNameFilter` | No | `*` | Wildcard filter on computer names (AD mode only) |
| `-OutputPath` | No | `.\Windows11EnterpriseAudit.csv` | Path for the exported CSV |

---

## Usage

**Query from a computer list**

Create a plain text file with one computer name per line, then run:

```powershell
.\Get-WindowsEditionAudit.ps1 -Mode List -ComputerListPath .\computers.txt
```

**Query from Active Directory**

Pulls all Windows computers from AD automatically:

```powershell
.\Get-WindowsEditionAudit.ps1 -Mode AD
```

**Filter by naming convention**

Useful if you want to scope to a specific OU-aligned name pattern:

```powershell
.\Get-WindowsEditionAudit.ps1 -Mode AD -ADNameFilter "VM-*"
```

**Specify a custom output path**

```powershell
.\Get-WindowsEditionAudit.ps1 -Mode AD -OutputPath "C:\Reports\EditionAudit.csv"
```

---

## Output

### Console summary

```
Windows Edition Audit
Mode: AD

Found 42 target computer(s). Querying...

ComputerName     OSName                          Version       BuildNumber  Reachable
------------     ------                          -------       -----------  ---------
DESKTOP-001      Windows 11 Enterprise           10.0.22631    22631        True
DESKTOP-002      Windows 11 Pro                  10.0.22631    22631        True
DESKTOP-003      Unreachable or access denied                               False

Summary
  Total targets:          42
  Reachable:              40
  Running Enterprise:     37
  Not Enterprise:         3
```

### CSV columns

| Column | Description |
|---|---|
| `ComputerName` | Name of the queried machine |
| `OSName` | Full OS caption as reported by the device |
| `Version` | Windows version string |
| `BuildNumber` | Windows build number |
| `SourceMode` | Whether the target came from List or AD |
| `Reachable` | True if the machine responded, False if it was unreachable or access was denied |

Unreachable machines are included in output with `Reachable = False` so you have a complete picture of what was attempted versus what responded.

---

## What to look for

When you run this against your environment, you are looking for a few things:

**Devices showing Windows 11 Pro instead of Enterprise**  
These machines may have incomplete licensing assignment, a broken Entra ID join, or they were never enrolled in Intune. Each of these has a different fix.

**Devices showing older Windows versions entirely**  
These are candidates for your Windows 10 end-of-support cleanup. Windows 10 reached end of support on October 14, 2025.

**High unreachable count**  
A large number of unreachable machines can indicate WinRM is not enabled, firewall rules are blocking access, or those machines are offline. Cross-reference with your Intune or ConfigMgr inventory to fill the gaps.

---

## Validating the conditions behind the result

The script tells you what each device is reporting. To understand *why* a device is not on Enterprise, the answer is usually in one of these places:

- [Microsoft Intune device inventory](https://learn.microsoft.com/en-us/mem/intune/remote-actions/device-inventory) shows how devices appear in your management plane
- [Microsoft Entra ID device join state](https://learn.microsoft.com/en-us/entra/identity/devices/concept-device-join-options) validates the identity prerequisites for subscription activation
- [Windows subscription activation documentation](https://learn.microsoft.com/en-us/windows/deployment/windows-10-subscription-activation) explains the full activation path and what can cause it to fall back

---

## License

MIT License. See [LICENSE](LICENSE) for details.
