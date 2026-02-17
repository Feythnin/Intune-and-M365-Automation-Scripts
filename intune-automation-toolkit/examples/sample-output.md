# Sample Output

These are example outputs showing what each script produces. All data is fictional.

## Get-StaleDevices.ps1

```
Querying managed devices...

Found 12 stale devices (inactive > 30 days)
==========================================
  Windows: 8 devices
  macOS: 3 devices
  iOS: 1 devices

DeviceName       UserPrincipalName         OperatingSystem  LastSync    DaysSinceSync ComplianceState
----------       -----------------         ---------------  --------    ------------- ---------------
DESKTOP-OLD01    jsmith@contoso.com        Windows          2024-11-15  93            noncompliant
DESKTOP-TEMP03   contractor@contoso.com    Windows          2024-12-01  77            noncompliant
MBP-MARKETING    mjones@contoso.com        macOS            2024-12-10  68            unknown
LAPTOP-SALES05   bwilson@contoso.com       Windows          2024-12-20  58            noncompliant
...
```

## Get-ComplianceReport.ps1

```
========================================
  COMPLIANCE REPORT
  Generated: 2025-02-15 14:30
========================================

Total Managed Devices: 247
  Compliant:     198 (80.2%)
  Non-Compliant: 38
  Unknown/Other: 11

By Operating System:
  Windows: 185 devices (82.7% compliant)
  macOS: 42 devices (76.2% compliant)
  iOS: 15 devices (73.3% compliant)
  Android: 5 devices (80.0% compliant)

Encryption Status:
  Encrypted: 221 / 247 (89.5%)

Non-Compliant Devices:
DeviceName       UserPrincipalName         OperatingSystem  OSVersion    LastSync
----------       -----------------         ---------------  ---------    --------
DESKTOP-DEV02    alee@contoso.com          Windows          10.0.19045   2025-02-14
MBP-DESIGN01    rgarcia@contoso.com       macOS            13.5.2       2025-02-13
...
```

## Export-DeviceInventory.ps1

```
Inventory Summary
=================
Total devices: 247
  Windows: 185
  macOS: 42
  iOS: 15
  Android: 5
  Dell Inc.: 98 devices
  Lenovo: 52 devices
  Apple: 57 devices
  HP: 40 devices

WARNING: 3 devices with >90% storage used:
DeviceName       UserPrincipalName         TotalStorageGB FreeStorageGB StorageUsedPercent
----------       -----------------         -------------- ------------- ------------------
DESKTOP-DEV02    alee@contoso.com          256.0          12.3          95.2
LAPTOP-HR01      jdoe@contoso.com          512.0          38.1          92.6
DESKTOP-ACCT03   kpatel@contoso.com        256.0          18.7          92.7

Inventory exported to: .\DeviceInventory_20250215.csv
```
