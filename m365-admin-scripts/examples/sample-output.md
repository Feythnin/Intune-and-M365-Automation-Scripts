# Sample Output

All data below is fictional.

## Get-SharedMailboxReport.ps1

```
========================================
  SHARED MAILBOX REPORT
========================================

Total Shared Mailboxes: 14
Mailboxes with NO delegates: 2
Hidden from GAL: 3

DisplayName          EmailAddress                FullAccessCount SendAsCount SendOnBehalfCount
-----------          ------------                --------------- ----------- -----------------
Reception            reception@contoso.com       4               2           0
Info                 info@contoso.com            6               3           2
Billing              billing@contoso.com         3               1           0
HR Inbox             hr@contoso.com              2               2           1
Sales Inquiries      sales@contoso.com           5               2           0
...
```

## Get-LicenseReport.ps1

```
========================================
  LICENSE USAGE REPORT
  Tenant: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
  Generated: 2025-02-15 14:30
========================================

License                              Total  Assigned  Available  UsagePercent  Status
-------                              -----  --------  ---------  ------------  ------
Microsoft 365 E3                     100    87        13         87.0%         Enabled
Exchange Online Plan 1               25     22        3          88.0%         Enabled
Microsoft 365 Business Basic         50     41        9          82.0%         Enabled
Power BI Pro                         20     8         12         40.0%         Enabled
Visio Plan 2                         5      5         0          100.0%        Enabled

WARNING: Licenses at or near capacity:
  Visio Plan 2: 0 remaining of 5

Total licenses: 200 | Assigned: 163 | Unused: 37
TIP: 37 unused licenses across all SKUs — review for potential cost savings.
```

## Get-InactiveUserReport.ps1

```
========================================
  INACTIVE USER REPORT
  Threshold: 90 days
========================================

Total inactive users: 18
Never signed in: 3
Enabled but inactive: 12
Licensed but inactive: 15 (potential cost savings)
Disabled WITH licenses still assigned: 4 (wasting licenses!)

By Department:
  Marketing: 5
  Sales: 4
  Engineering: 3

DisplayName      UserPrincipalName         Enabled  Licenses  LastSignIn   DaysSince
-----------      -----------------         -------  --------  ----------   ---------
Former Employee  jdoe@contoso.com          False    2         2024-08-15   184
Contractor       temp@contoso.com          False    1         2024-09-01   167
Test Account     test@contoso.com          True     1         Never        Never
...
```

## Get-MailboxPermissionAudit.ps1

```
========================================
  MAILBOX PERMISSION AUDIT
  Generated: 2025-02-15 14:30
========================================

Mailboxes scanned: 87
Total permission entries: 142

By Permission Type:
  Full Access: 68
  Send As: 45
  Send on Behalf: 29

Top 10 Most-Delegated Mailboxes:
  info@contoso.com: 11 delegates
  reception@contoso.com: 8 delegates
  billing@contoso.com: 6 delegates

Top 10 Users with Most Access:
  admin@contoso.com: access to 14 mailboxes
  jsmith@contoso.com: access to 8 mailboxes
```
