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

## Get-TransportRuleReport.ps1

```
========================================
  TRANSPORT RULE REPORT
  Generated: 2025-02-15 14:30
========================================

Total rules: 6
  Enabled:  5
  Disabled: 1

[0] External Email Warning Banner (Enabled)
  Conditions: From scope: NotInOrganization
  Actions:    Prepend subject: [EXTERNAL]

[1] Block Executable Attachments (Enabled)
  Conditions: Attachment has executable content
  Actions:    Reject with: Executable attachments are not allowed.

[2] BCC Compliance on Legal (Enabled)
  Conditions: Recipient domain: legal-partner.com
  Actions:    BCC to: compliance@contoso.com
  Exceptions: Has exceptions

[3] Redirect Former Employee Mail (Enabled)
  Conditions: From contains: jdoe
  Actions:    Redirect to: manager@contoso.com
...
```

## Get-ServiceHealthDashboard.ps1

```
Querying service health status...

========================================
  SERVICE HEALTH DASHBOARD
  Tenant: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
  Generated: 2025-02-15 14:30
========================================

Services: 28 total
  Healthy:  26
  Degraded: 2
Active incidents:  1
Active advisories: 2

Service Statuses:
  Exchange Online: Degraded
  Microsoft Teams: Degraded
  SharePoint Online: Operational
  Microsoft 365 Apps: Operational
  Microsoft Entra: Operational
  Microsoft Intune: Operational
  Power BI: Operational
  ...

Issues (3):

  [INCIDENT] Exchange Online - Delayed email delivery
    Service: Exchange Online | Status: Active | Started: 2025-02-15 08:12
    Impact: Users may experience delays of up to 30 minutes when sending or receiving email.

  [ADVISORY] Microsoft Teams - Intermittent issues joining meetings
    Service: Microsoft Teams | Status: Active | Started: 2025-02-15 10:45
    Impact: Some users may experience issues when attempting to join Teams meetings.

  [ADVISORY] SharePoint Online - Search index delay
    Service: SharePoint Online | Status: Active | Started: 2025-02-14 22:00
    Impact: Recently uploaded documents may take longer than expected to appear in search results.
```

## Get-MFAStatusReport.ps1

```
Querying MFA registration details...
Retrieved registration details for 112 users.

========================================
  MFA STATUS REPORT
  Tenant: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
  Generated: 2025-02-15 14:30
========================================

Total users: 112
MFA registered: 97 (86.6%)
No MFA: 15
SMS-only MFA: 8 (consider stronger methods)

Method Breakdown:
  microsoftAuthenticator: 78
  phoneAuthentication: 32
  fido2: 12
  windowsHelloForBusiness: 45
  email: 18
  softwareOneTimePasscode: 5

Enabled users WITHOUT MFA:
  contractor1@contoso.com
  temp.account@contoso.com
  conference.room1@contoso.com
  service.desk@contoso.com
  ...

DisplayName            UserPrincipalName            Enabled  MfaRegistered  DefaultMethod                 SmsOnly
-----------            -----------------            -------  -------------  -------------                 -------
Alice Johnson          ajohnson@contoso.com         True     True           microsoftAuthenticator        False
Bob Wilson             bwilson@contoso.com          True     True           phoneAuthentication           True
Contractor 1           contractor1@contoso.com      True     False          None                          False
...
```

## Get-GuestAccessAudit.ps1

```
Querying guest user accounts...
Found 34 guest users. Processing...

========================================
  GUEST ACCESS AUDIT
  Staleness Threshold: 90 days
  Generated: 2025-02-15 14:30
========================================

Total guest users: 34
Stale guests (>90 days): 12
Never signed in: 5
Pending invitations: 3

Top Source Domains:
  partner-corp.com: 8 guests
  vendor-inc.com: 6 guests
  agency.io: 5 guests
  consultant.net: 4 guests
  freelancer.com: 3 guests

DisplayName              Email                            InvitationState     LastSignIn   IsStale
-----------              -----                            ---------------     ----------   -------
Old Vendor Contact       vendor@partner-corp.com          Accepted            2024-08-01   True
Pending Invite           newguy@agency.io                 PendingAcceptance   Never        True
Active Partner           collab@vendor-inc.com            Accepted            2025-02-14   False
Former Contractor        temp@freelancer.com              Accepted            2024-06-15   True
...
```

## Get-AdminRoleReport.ps1

```
Querying directory role assignments...
Found 23 active role assignments.
Querying PIM eligible assignments...
Found 8 PIM eligible assignments.
Querying MFA registration details...

========================================
  ADMIN ROLE REPORT
  Tenant: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
  Generated: 2025-02-15 14:30
========================================

Total role assignments: 31
  Permanent: 23
  PIM Eligible: 8
Permanent Global Admins: 3
Admins without MFA: 2
Stale admin accounts (>90 days): 4

Assignments by Role:
  Global Administrator: 5
  Exchange Administrator: 4
  User Administrator: 6
  Security Administrator: 3
  Helpdesk Administrator: 5
  Intune Administrator: 3
  SharePoint Administrator: 2
  Teams Administrator: 3

DisplayName           RoleName                  AssignmentType  MfaRegistered  LastSignIn   IsStale
-----------           --------                  --------------  -------------  ----------   -------
IT Admin              Global Administrator      Permanent       True           2025-02-15   False
Break Glass           Global Administrator      Permanent       True           2024-05-01   True
Service Account       Global Administrator      Permanent       Unknown        Never        True
CTO                   Global Administrator      PIM Eligible    True           2025-02-14   False
Helpdesk Lead         Helpdesk Administrator    Permanent       True           2025-02-15   False
New Admin             User Administrator        Permanent       False          2025-02-10   False
...
```

## Get-ConditionalAccessReport.ps1

```
Querying Conditional Access policies...
Found 8 policies. Resolving names...

========================================
  CONDITIONAL ACCESS REPORT
  Tenant: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
  Generated: 2025-02-15 14:30
========================================

Total policies: 8
  Enabled:     5
  Report-only: 3
Policies requiring MFA: 4

  [ON] Require MFA for All Users
    Users:    Include=All Users | Exclude=Break Glass Account
    Groups:   Include=None | Exclude=None
    Grants:   (OR) mfa
    Sessions: Sign-in frequency: 12 hours

  [ON] Block Legacy Authentication
    Users:    Include=All Users | Exclude=None
    Groups:   Include=None | Exclude=None
    Grants:   (OR) block

  [ON] Require Compliant Device for Office 365
    Users:    Include=All Users | Exclude=Service Accounts
    Groups:   Include=None | Exclude=IT Admins
    Grants:   (AND) mfa, compliantDevice

  [ON] Require MFA for Admins
    Users:    Include=None | Exclude=Break Glass Account
    Groups:   Include=Admin Role Group | Exclude=None
    Grants:   (OR) mfa

  [ON] Block High Risk Sign-ins
    Users:    Include=All Users | Exclude=None
    Groups:   Include=None | Exclude=None
    Grants:   (OR) block

  [REPORT-ONLY] Require MFA for Guest Access
    Users:    Include=Guests/External Users | Exclude=None
    Groups:   Include=None | Exclude=None
    Grants:   (OR) mfa

  [REPORT-ONLY] Require App Protection Policy
    Users:    Include=All Users | Exclude=None
    Groups:   Include=None | Exclude=IT Admins
    Grants:   (OR) approvedApplication

  [REPORT-ONLY] Block Unmanaged Devices
    Users:    Include=All Users | Exclude=Service Accounts
    Groups:   Include=None | Exclude=None
    Grants:   (OR) compliantDevice
```

## Export-ConditionalAccessBackup.ps1

```
Querying Conditional Access policies...
Found 8 policies to export.
  Exported: Require MFA for All Users (Enabled)
  Exported: Block Legacy Authentication (Enabled)
  Exported: Require Compliant Device for Office 365 (Enabled)
  Exported: Require MFA for Admins (Enabled)
  Exported: Block High Risk Sign-ins (Enabled)
  Exported: Require MFA for Guest Access (ReportOnly)
  Exported: Require App Protection Policy (ReportOnly)
  Exported: Block Unmanaged Devices (ReportOnly)

========================================
  CONDITIONAL ACCESS BACKUP
  Generated: 2025-02-15 14:30
========================================

Policies exported: 8
  Enabled:     5
  Report-only: 3

Output directory: C:\Scripts\CA-Backup_2025-02-15_143012
Manifest: _manifest.json
```

## Get-TeamsGovernanceReport.ps1

```
Querying Teams-enabled groups...
Found 42 teams. Gathering details...
Fetching Teams activity report...
Activity data loaded for 42 teams.

========================================
  TEAMS GOVERNANCE REPORT
  Inactivity Threshold: 90 days
  Generated: 2025-02-15 14:30
========================================

Total teams: 42
  Public:  15
  Private: 27
Ownerless teams: 3
Inactive teams (>90 days): 8
Teams with guests: 12

Ownerless Teams:
  Old Project Alpha
  Temp - Summer Interns 2024
  Vendor Collaboration (Archived)

TeamName                     Visibility  OwnerCount  MemberCount  GuestCount  LastActivity  IsInactive  IsOwnerless
--------                     ----------  ----------  -----------  ----------  ------------  ----------  -----------
Engineering                  Private     3           28           0           2025-02-15    False       False
Marketing                    Private     2           15           2           2025-02-14    False       False
All Company                  Public      4           98           0           2025-02-15    False       False
Old Project Alpha            Private     0           12           0           2024-09-20    True        True
Temp - Summer Interns 2024   Public      0           8            3           2024-08-30    True        True
Sales - External Partners    Private     2           10           5           2025-02-13    False       False
...
```

## Invoke-UserOffboard.ps1

```
[2025-02-15 14:30:00] [INFO] === User Offboarding Started ===
[2025-02-15 14:30:00] [INFO] Users to process: 2

========================================
  USER OFFBOARDING
  Users to process: 2
========================================

[2025-02-15 14:30:01] [INFO] Processing: jdoe@contoso.com
[2025-02-15 14:30:01] [SUCCESS]   Disabled account: jdoe@contoso.com
[2025-02-15 14:30:02] [SUCCESS]   Revoked sessions: jdoe@contoso.com
[2025-02-15 14:30:02] [SUCCESS]   Converted to shared mailbox: jdoe@contoso.com
[2025-02-15 14:30:03] [SUCCESS]   Set forwarding to manager@contoso.com for jdoe@contoso.com
[2025-02-15 14:30:03] [SUCCESS]   Removed 3 licenses from jdoe@contoso.com
[2025-02-15 14:30:04] [SUCCESS]   Removed from 7 groups: jdoe@contoso.com
[2025-02-15 14:30:04] [SUCCESS]   Hidden from GAL: jdoe@contoso.com

[2025-02-15 14:30:05] [INFO] Processing: contractor@contoso.com
[2025-02-15 14:30:05] [SUCCESS]   Disabled account: contractor@contoso.com
[2025-02-15 14:30:06] [SUCCESS]   Revoked sessions: contractor@contoso.com
[2025-02-15 14:30:06] [SUCCESS]   Converted to shared mailbox: contractor@contoso.com
[2025-02-15 14:30:07] [SUCCESS]   Set forwarding to manager@contoso.com for contractor@contoso.com
[2025-02-15 14:30:07] [SUCCESS]   Removed 1 licenses from contractor@contoso.com
[2025-02-15 14:30:08] [WARN]   Could not remove from group IT Admins: Insufficient privileges
[2025-02-15 14:30:08] [SUCCESS]   Removed from 4 groups: contractor@contoso.com
[2025-02-15 14:30:08] [SUCCESS]   Hidden from GAL: contractor@contoso.com

========================================
[2025-02-15 14:30:09] [INFO] === Offboarding Complete ===
[2025-02-15 14:30:09] [INFO] Succeeded: 1 | Partial: 1 | Failed: 0 | Total: 2
Licenses reclaimed: 4
Groups removed: 11
Mailboxes converted to shared: 2

UserPrincipalName         DisplayName        Status   LicensesReclaimed  GroupsRemoved
-----------------         -----------        ------   -----------------  -------------
jdoe@contoso.com          John Doe           Success  3                  7
contractor@contoso.com    Temp Contractor    Partial  1                  4
```
