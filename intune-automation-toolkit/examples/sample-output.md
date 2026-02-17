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

## Get-ConfigProfileReport.ps1

```
Querying device configuration profiles...
Found 9 configuration profile(s). Checking status...

  Checking: WiFi - Corporate...
  Checking: VPN - Always On...
  Checking: BitLocker Encryption...
  Checking: Windows Hello for Business...
  Checking: Device Restrictions - Windows...
  Checking: Email Profile - iOS...
  Checking: Compliance - Passcode...
  Checking: Firewall - Windows...
  Checking: Edge Browser Settings...

========================================
  CONFIGURATION PROFILE REPORT
  Generated: 2025-02-15 14:30
========================================

Profiles: 9
Total errors across all profiles: 7
Total conflicts across all profiles: 3

ProfileName                    TotalDevices  Succeeded  Error  Conflict  Pending  SuccessRate
-----------                    ------------  ---------  -----  --------  -------  -----------
WiFi - Corporate               185          181        3      1         0        97.8%
VPN - Always On                 185          178        4      3         0        96.2%
BitLocker Encryption            185          185        0      0         0        100%
Windows Hello for Business      185          183        2      0         0        98.9%
Device Restrictions - Windows   185          185        0      0         0        100%
Email Profile - iOS             15           14         1      0         0        93.3%
Compliance - Passcode           200          197        0      0         3        98.5%
Firewall - Windows              185          185        0      0         0        100%
Edge Browser Settings           185          182        0      3         0        98.4%

Error Details:
ProfileName           DeviceName        UserPrincipal           LastReported
-----------           ----------        -------------           ------------
WiFi - Corporate      DESKTOP-DEV02    alee@contoso.com        2025-02-14
WiFi - Corporate      LAPTOP-TEMP03    contractor@contoso.com  2025-02-13
VPN - Always On       MBP-DESIGN01    rgarcia@contoso.com     2025-02-14
...
```

## Get-WindowsUpdateCompliance.ps1

```
Querying Windows device update compliance...
Found 185 Windows devices.

========================================
  WINDOWS UPDATE COMPLIANCE
  Generated: 2025-02-15 14:30
========================================

Total Windows devices: 185
Minimum build: 10.0.22631.3007
  Current:  162 (87.6%)
  Outdated: 23

OS Build Distribution:
  10.0.22631: 112 devices (60.5%)
  10.0.22621: 45 devices (24.3%)
  10.0.19045: 23 devices (12.4%)
  10.0.19044: 5 devices (2.7%)

Compliance State:
  compliant: 153
  noncompliant: 27
  unknown: 5

Encrypted: 178 / 185 (96.2%)

Devices not synced in 14+ days: 4

Outdated Devices:
DeviceName        UserPrincipalName         OSVersion       LastSync
----------        -----------------         ---------       --------
DESKTOP-OLD01     jsmith@contoso.com        10.0.19044.3803 2025-02-10
DESKTOP-ACCT03    kpatel@contoso.com        10.0.19045.3930 2025-02-14
LAPTOP-SALES05    bwilson@contoso.com       10.0.19045.3803 2025-02-12
...
```

## Get-BitLockerStatus.ps1

```
Querying BitLocker encryption status...
Found 185 Windows devices. Checking encryption and recovery keys...
Found recovery keys for 172 device(s).

========================================
  BITLOCKER STATUS REPORT
  Generated: 2025-02-15 14:30
========================================

Total Windows devices: 185
Encrypted: 178 (96.2%)
NOT encrypted: 7
Recovery keys escrowed: 172
Encrypted WITHOUT recovery key: 6

Unencrypted Devices:
DeviceName        UserPrincipalName         OSVersion       ComplianceState  LastSync
----------        -----------------         ---------       ---------------  --------
DESKTOP-OLD01     jsmith@contoso.com        10.0.19044      noncompliant     2025-02-10
LAPTOP-TEMP03     contractor@contoso.com    10.0.22621      noncompliant     2025-02-13
DESKTOP-LAB02     labuser@contoso.com       10.0.22631      unknown          2025-02-08
...

Encrypted Devices Missing Recovery Key:
DeviceName        UserPrincipalName         OSVersion
----------        -----------------         ---------
LAPTOP-HR01       jdoe@contoso.com          10.0.22631
DESKTOP-EXEC04    cfo@contoso.com           10.0.22631
...
```

## Get-RemediationStatus.ps1

```
Querying proactive remediation scripts...
Found 4 remediation script(s). Gathering results...

  Checking: Stale Certificate Cleanup...
  Checking: Teams Cache Reset...
  Checking: Restart Print Spooler...
  Checking: Clear Temp Files...

========================================
  PROACTIVE REMEDIATION STATUS
  Generated: 2025-02-15 14:30
========================================

Remediation scripts: 4
Total successful remediations: 42
Total failed remediations: 3
Total detection failures: 5

Per-Script Summary:
ScriptName                 TotalDevices  DetectionSuccess  DetectionFailed  RemediationSuccess  RemediationFailed
----------                 ------------  ----------------  ---------------  ------------------  -----------------
Stale Certificate Cleanup  185           180               3                28                  1
Teams Cache Reset          185           183               2                12                  0
Restart Print Spooler      185           185               0                2                   2
Clear Temp Files           185           185               0                0                   0

Failed Executions:
ScriptName                 DeviceName        DetectionState  RemediationState
----------                 ----------        --------------  ----------------
Stale Certificate Cleanup  DESKTOP-DEV02    scriptError     N/A
Stale Certificate Cleanup  LAPTOP-TEMP03    fail            N/A
Restart Print Spooler      DESKTOP-OLD01    success         remediationFailed
...
```

## Get-AppProtectionReport.ps1

```
Querying app protection policies...
Found 3 app protection policy/policies. Gathering details...

  Checking: Corporate Data Protection (iOS)...
  Checking: Corporate Data Protection (Android)...
  Checking: BYOD App Protection (iOS)...

========================================
  APP PROTECTION POLICY REPORT
  Generated: 2025-02-15 14:30
========================================

Total policies: 3
  iOS: 2 policy/policies
  Android: 1 policy/policies
Total users covered: 67
Users with failures: 2

PolicyName                        Platform  IsAssigned  DeployedUsers  AppliedUsers  FailedUsers  KeySettings
----------                        --------  ----------  -------------  ------------  -----------  -----------
Corporate Data Protection         iOS       True        45             43            1            PIN required; Save-as blocked; Backup blocked
Corporate Data Protection         Android   True        22             21            1            PIN required; Biometrics allowed; Save-as blocked
BYOD App Protection               iOS       True        18             18            0            PIN required; Managed browser required; Min OS: 16.0
```
