# odscex PowerShell Module

[![GitHub Release](https://img.shields.io/github/v/release/valar12/odscex?label=GitHub%20Release)](https://github.com/valar12/odscex/releases)
[![PowerShell Gallery Release](https://img.shields.io/powershellgallery/v/odscex)](https://www.powershellgallery.com/packages/odscex)
[![License](https://img.shields.io/badge/license-MIT-green)](https://github.com/valar12/odscex/blob/main/LICENSE.md)
[![GitHub Last Commit](https://img.shields.io/github/last-commit/valar12/odscex)](https://github.com/valar12/odscex/commits/main)

#### Table of Contents

* [Overview](#overview)
* [What's New](#whats-new)
* [Installation](#installation)
* [Prerequisites](#prerequisites)
* [National cloud support](#national-cloud-support)
* [Usage](#usage)
* [Single-user shortcut management](#single-user-shortcut-management)
* [Organization-scale management](#organization-scale-management)
* [Desired-state plan files](#desired-state-plan-files)
* [Reporting and audit output](#reporting-and-audit-output)
* [Advanced Graph operations](#advanced-graph-operations)
* [Troubleshooting](#troubleshooting)
* [Licensing](#licensing)

----------

## Overview

odscex is a [PowerShell](https://microsoft.com/powershell) [module](https://technet.microsoft.com/en-us/library/dd901839.aspx)
that provides CLI access to managing SharePoint shortcuts in OneDrive. It supports both single-user shortcut operations and organization-scale desired-state assignments for groups, CSV targets, filtered users, or all users.

The expanded organization management surface is intended for repeatable administrative runs. You can resolve users, validate access, apply shortcuts idempotently, remove shortcuts, export reports, and define shortcuts in a plan file for scheduled or CI/CD-driven deployments.

## What's New

Check out [CHANGELOG.md](CHANGELOG.md) to review the details of all releases.

## Installation

You can get latest release of the odscex module on the [PowerShell Gallery](https://www.powershellgallery.com/packages/odscex)

```PowerShell
$InstallParameters = @{
    Name = 'odscex'
}

Install-Module @InstallParameters
```

## Prerequisites

To use this module you need a Microsoft Entra application registration that can authenticate to Microsoft Graph. At a minimum, collect or configure:

* Tenant ID
* Client ID / Application ID
* Client secret or certificate
* Microsoft Graph application permissions for the operations you will run
* Admin consent for those permissions

Broad organization-scale deployments commonly require permissions such as `Files.ReadWrite.All`, `Sites.ReadWrite.All`, and `User.Read.All`. Targeting users by group also requires permission to read group membership. Use the least-privilege model your tenant supports, and validate access before a broad rollout.

## National cloud support

odscex can authenticate and send Microsoft Graph requests to multiple Microsoft cloud environments. Use `Connect-odscex -Cloud` instead of manually setting endpoints.

| Cloud | Microsoft Graph endpoint | Notes |
| --- | --- | --- |
| `Global` | `https://graph.microsoft.com` | Default worldwide Microsoft Graph service. |
| `GCC` | `https://graph.microsoft.com` | Microsoft 365 GCC uses worldwide Microsoft Graph endpoints. |
| `GCCHigh` | `https://graph.microsoft.us` | Microsoft Graph for US Government L4 / GCC High. |
| `DoD` | `https://dod-graph.microsoft.us` | Microsoft Graph for US Government L5 / DoD. |
| `China` | `https://microsoftgraph.chinacloudapi.cn` | Microsoft Graph China operated by 21Vianet. |

Example GCC connection:

```powershell
$ClientSecretParameters = @{
    String = 'client-secret'
    AsPlainText = $true
    Force = $true
}

$ConnectParameters = @{
    Cloud = 'GCC'
    TenantId = '00000000-0000-0000-0000-000000000000'
    ClientId = '00000000-0000-0000-0000-000000000000'
    ClientSecret = ConvertTo-SecureString @ClientSecretParameters
}

Connect-odscex @ConnectParameters
```

Example GCC High connection:

```powershell
$CertificateParameters = @{
    Path = 'Cert:\CurrentUser\My\0000000000000000000000000000000000000000'
}
$Certificate = Get-Item @CertificateParameters
$ConnectParameters = @{
    Cloud = 'GCCHigh'
    TenantId = '00000000-0000-0000-0000-000000000000'
    ClientId = '00000000-0000-0000-0000-000000000000'
    ClientCertificate = $Certificate
}

Connect-odscex @ConnectParameters
```

After connection, every module command uses a token scoped to the selected cloud's Graph resource and sends requests to that cloud's Graph endpoint until `Disconnect-odscex` is called or another `Connect-odscex` call selects a different cloud. Advanced callers can use `-GraphEndpoint` to override the Graph root endpoint when required.

## Usage

Connect with a client secret:

```powershell
$ClientSecretParameters = @{
    String = 'client-secret'
    AsPlainText = $true
    Force = $true
}

$ConnectParameters = @{
    TenantId = '00000000-0000-0000-0000-000000000000'
    ClientId = '00000000-0000-0000-0000-000000000000'
    ClientSecret = ConvertTo-SecureString @ClientSecretParameters
}

Connect-odscex @ConnectParameters
```

Connect with a certificate:

```powershell
$CertificateParameters = @{
    Path = 'Cert:\CurrentUser\My\0000000000000000000000000000000000000000'
}
$Certificate = Get-Item @CertificateParameters
$ConnectParameters = @{
    TenantId = '00000000-0000-0000-0000-000000000000'
    ClientId = '00000000-0000-0000-0000-000000000000'
    ClientCertificate = $Certificate
}

Connect-odscex @ConnectParameters
```

Disconnect when finished:

```powershell
Disconnect-odscex
```

For full command-level help, run:

```powershell
$HelpParameters = @{
    Name = '<commandName>'
    Full = $true
}

Get-Help @HelpParameters
```

For additional examples, see [USAGE.md](USAGE.md).

## Single-user shortcut management

### Get a user's OneDrive drive metadata

```powershell
$DriveParameters = @{
    UserPrincipalName = 'user@contoso.com'
}

Get-odscexDrive @DriveParameters
```

### Create a shortcut to a document library

```powershell
$ShortcutParameters = @{
    Uri = 'https://contoso.sharepoint.com/sites/WorkingSite'
    DocumentLibrary = 'Documents'
    ShortcutName = 'Working Documents'
    UserPrincipalName = 'user@contoso.com'
}

New-odscex @ShortcutParameters
```

### Create a shortcut to a document library folder

```powershell
$ShortcutParameters = @{
    Uri = 'https://contoso.sharepoint.com/sites/WorkingSite'
    DocumentLibrary = 'Documents'
    FolderPath = 'Department/Policies'
    ShortcutName = 'Department Policies'
    UserPrincipalName = 'user@contoso.com'
}

New-odscex @ShortcutParameters
```

### Place the shortcut in a OneDrive subfolder

```powershell
$ShortcutParameters = @{
    Uri = 'https://contoso.sharepoint.com/sites/WorkingSite'
    DocumentLibrary = 'Documents'
    RelativePath = 'Company/Shortcuts'
    ShortcutName = 'Working Documents'
    UserPrincipalName = 'user@contoso.com'
}

New-odscex @ShortcutParameters
```

### Troubleshoot OneDrive 404 errors

When Microsoft Graph returns `StatusCode: 404` for a resource such as
`users/<user>/drive/root/children` or `users/<user>/drive/root`, the shortcut target
may have resolved successfully but the destination OneDrive could not be opened.
Check that the `UserPrincipalName` is spelled correctly, the user's OneDrive has been
provisioned at least once, and the account has a SharePoint/OneDrive license. If the
user's sign-in name recently changed, retry with `-UserObjectId` so Graph does not
depend on the UPN alias. For target-side 404 errors, verify that `-Uri` is the site URL
(not a library or folder URL), `-DocumentLibrary` is the library display name, and
`-FolderPath` is relative to the library root. For example, if the browser URL is
`https://contoso.sharepoint.com/Shared%20Documents/Forms/AllItems.aspx`, use the site
URL `https://contoso.sharepoint.com`, the library display name `Documents`, and a
folder path such as `2025-06-25` or `Department/Policies`. You can validate access
before creating the shortcut:

```powershell
Test-odscexPermission -Uri 'https://contoso.sharepoint.com/sites/WorkingSite' -DocumentLibrary 'Documents' -UserPrincipalName 'user@contoso.com'
Get-odscexDrive -UserPrincipalName 'user@contoso.com'
```

### Converge a shortcut with desired-state behavior

`Set-odscexShortcutState` is the recommended command for repeatable automation. If the shortcut already points to the requested SharePoint target, the command reports `Compliant` instead of creating a duplicate.

```powershell
$ShortcutStateParameters = @{
    Uri = 'https://contoso.sharepoint.com/sites/WorkingSite'
    DocumentLibrary = 'Documents'
    ShortcutName = 'Working Documents'
    UserPrincipalName = 'user@contoso.com'
    State = 'Present'
    ConflictAction = 'Skip'
}

Set-odscexShortcutState @ShortcutStateParameters
```

### Replace a conflicting shortcut

```powershell
$ShortcutStateParameters = @{
    Uri = 'https://contoso.sharepoint.com/sites/WorkingSite'
    DocumentLibrary = 'Documents'
    ShortcutName = 'Working Documents'
    UserPrincipalName = 'user@contoso.com'
    State = 'Present'
    ConflictAction = 'Replace'
}

Set-odscexShortcutState @ShortcutStateParameters
```

### Remove a shortcut

```powershell
$RemoveParameters = @{
    ShortcutName = 'Working Documents'
    UserPrincipalName = 'user@contoso.com'
    PassThru = $true
}

Remove-odscex @RemoveParameters
```

## Organization-scale management

Use `Get-odscexTargetUser` to resolve users, then apply a desired shortcut state with `Invoke-odscexShortcutAssignment` or `Invoke-odscexApply`.

### Validate permissions before rollout

```powershell
$PermissionParameters = @{
    Uri = 'https://contoso.sharepoint.com/sites/WorkingSite'
    UserPrincipalName = 'pilot.user@contoso.com'
}

Test-odscexPermission @PermissionParameters
```

### Assign a shortcut to all members of a group

```powershell
$TargetUserParameters = @{
    GroupId = '00000000-0000-0000-0000-000000000000'
}
$Users = Get-odscexTargetUser @TargetUserParameters

$AssignmentParameters = @{
    User = $Users
    Uri = 'https://contoso.sharepoint.com/sites/WorkingSite'
    DocumentLibrary = 'Documents'
    ShortcutName = 'Working Documents'
    State = 'Present'
    ConflictAction = 'Skip'
    ReportPath = '.\odscex-group-results.csv'
}

Invoke-odscexShortcutAssignment @AssignmentParameters
```

### Assign a shortcut to users from a CSV file

The CSV should contain `UserPrincipalName`, `UserObjectId`, or `Id` columns.

```powershell
$TargetUserParameters = @{
    CsvPath = '.\users.csv'
}
$Users = Get-odscexTargetUser @TargetUserParameters

$AssignmentParameters = @{
    User = $Users
    Uri = 'https://contoso.sharepoint.com/sites/WorkingSite'
    DocumentLibrary = 'Documents'
    ShortcutName = 'Working Documents'
    ReportPath = '.\odscex-csv-results.json'
    OutputFormat = 'Json'
}

Invoke-odscexShortcutAssignment @AssignmentParameters
```

### Assign a shortcut to filtered users

```powershell
$TargetUserParameters = @{
    Filter = 'accountEnabled eq true'
}
$Users = Get-odscexTargetUser @TargetUserParameters

$AssignmentParameters = @{
    User = $Users
    Uri = 'https://contoso.sharepoint.com/sites/WorkingSite'
    DocumentLibrary = 'Documents'
    ShortcutName = 'Working Documents'
    State = 'Present'
}

Invoke-odscexShortcutAssignment @AssignmentParameters
```

### Assign a shortcut to all users

```powershell
$TargetUserParameters = @{
    AllUsers = $true
}
$Users = Get-odscexTargetUser @TargetUserParameters

$AssignmentParameters = @{
    User = $Users
    Uri = 'https://contoso.sharepoint.com/sites/Company'
    DocumentLibrary = 'Documents'
    ShortcutName = 'Company Documents'
    State = 'Present'
    ReportPath = '.\odscex-all-users.csv'
}

Invoke-odscexShortcutAssignment @AssignmentParameters
```

### Remove a shortcut for a target population

```powershell
$TargetUserParameters = @{
    GroupId = '00000000-0000-0000-0000-000000000000'
}
$Users = Get-odscexTargetUser @TargetUserParameters

$AssignmentParameters = @{
    User = $Users
    Uri = 'https://contoso.sharepoint.com/sites/WorkingSite'
    DocumentLibrary = 'Documents'
    ShortcutName = 'Working Documents'
    State = 'Absent'
    ReportPath = '.\odscex-remove-results.csv'
}

Invoke-odscexShortcutAssignment @AssignmentParameters
```

### Preview changes with WhatIf

```powershell
$TargetUserParameters = @{
    CsvPath = '.\pilot-users.csv'
}
$Users = Get-odscexTargetUser @TargetUserParameters

$AssignmentParameters = @{
    User = $Users
    Uri = 'https://contoso.sharepoint.com/sites/WorkingSite'
    DocumentLibrary = 'Documents'
    ShortcutName = 'Working Documents'
    State = 'Present'
    WhatIf = $true
}

Invoke-odscexShortcutAssignment @AssignmentParameters
```

### Resume a large run

If a large run stops after processing some users, use `-ResumeFrom` to continue at a zero-based user index.

```powershell
$AssignmentParameters = @{
    User = $Users
    Uri = 'https://contoso.sharepoint.com/sites/WorkingSite'
    DocumentLibrary = 'Documents'
    ShortcutName = 'Working Documents'
    State = 'Present'
    ResumeFrom = 250
    ReportPath = '.\odscex-resumed-results.csv'
}

Invoke-odscexShortcutAssignment @AssignmentParameters
```

## Desired-state plan files

Plan files let you describe expected shortcuts once and reapply them on a schedule. `Invoke-odscexPlan` and `Invoke-odscexApply` support JSON and PowerShell data files.

### Example JSON plan

```json
{
  "shortcuts": [
    {
      "name": "HR Policies",
      "siteUrl": "https://contoso.sharepoint.com/sites/HR",
      "library": "Documents",
      "folderPath": "Policies",
      "oneDrivePath": "Company",
      "state": "Present",
      "target": {
        "groupId": "00000000-0000-0000-0000-000000000000"
      }
    },
    {
      "name": "Company Handbook",
      "siteUrl": "https://contoso.sharepoint.com/sites/Company",
      "library": "Documents",
      "state": "Present",
      "target": {
        "allUsers": true
      }
    }
  ]
}
```

Review the plan:

```powershell
$PlanParameters = @{
    Path = '.\shortcuts.json'
}

Invoke-odscexPlan @PlanParameters
```

Apply the plan and export a report:

```powershell
$ApplyParameters = @{
    Path = '.\shortcuts.json'
    ReportPath = '.\shortcut-apply.csv'
}

Invoke-odscexApply @ApplyParameters
```

Preview the plan without applying changes:

```powershell
$ApplyParameters = @{
    Path = '.\shortcuts.json'
    WhatIf = $true
}

Invoke-odscexApply @ApplyParameters
```

## Reporting and audit output

Organization-scale commands return structured result objects and can also write reports. The report format can be `Csv`, `Json`, or `Clixml`.

```powershell
$AssignmentParameters = @{
    User = $Users
    Uri = 'https://contoso.sharepoint.com/sites/WorkingSite'
    DocumentLibrary = 'Documents'
    ShortcutName = 'Working Documents'
    ReportPath = '.\shortcut-audit.clixml'
    OutputFormat = 'Clixml'
}

Invoke-odscexShortcutAssignment @AssignmentParameters
```

Common statuses include:

* `Created` - shortcut was created.
* `Compliant` - shortcut already pointed to the requested target.
* `AlreadyAbsent` - shortcut removal was requested and no matching shortcut existed.
* `Removed` - shortcut was removed.
* `SkippedConflict` - a same-named item existed and `-ConflictAction Skip` was used.
* `Failed` - the user assignment failed and the error was captured in the result object.

## Advanced Graph operations

`Invoke-odscexApiRequest` follows `@odata.nextLink` when callers request all pages and retries transient Microsoft Graph responses such as `429`, `500`, `502`, `503`, and `504`. Advanced callers can also submit JSON batches of up to 20 Microsoft Graph subrequests.

```powershell
$BatchParameters = @{
    Requests = @(
        @{ id = 'drive'; method = 'GET'; url = '/users/user@contoso.com/drive' }
        @{ id = 'site'; method = 'GET'; url = '/sites/contoso.sharepoint.com:/sites/WorkingSite' }
    )
}

Invoke-odscexGraphBatch @BatchParameters
```

## Troubleshooting

For admin-focused guidance on common setup and runtime issues, see [Troubleshooting](docs/troubleshooting.md). It covers authentication failures, permission errors, missing OneDrive provisioning, shortcut target resolution, relative path behavior, throttling, reporting, and national cloud endpoint checks.

## Licensing

odscex is licensed under the [MIT license](LICENSE.md).
