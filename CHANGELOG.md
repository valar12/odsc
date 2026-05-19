# CHANGELOG

## 0.6.3

* Recovered SharePoint list item unique IDs for folder targets when Graph omits `driveItem.sharepointIds`, avoiding drive-item-reference shortcuts that Graph rejects during OneDrive subfolder placement.
* Expanded OneDrive subfolder shortcut fallback moves to try combined move/rename requests, destination path parent references, and user-scoped item resources when Graph rejects the initial drive-scoped move.

## 0.6.2

* Fixed OneDrive subfolder shortcut placement by including the destination drive ID when moving fallback-created shortcuts.

## 0.6.1

* Added GitHub Actions CI to run the Pester test suite on push and pull request events.
* Added GitHub Actions publishing logic that packages the module for PowerShell Gallery releases.

## 0.6.0

* Refactored shortcut state handling into focused helpers for target matching, remote item references, drive item resources, fallback moves, and Graph error handling.
* Split SharePoint target resolution into site, document library, and folder resolver helpers.
* Centralized Microsoft Graph JSON body serialization in `Invoke-odscexApiRequest`.
* Added `New-odscex -DocumentLibraryId` support and updated command help.
* Expanded Pester coverage for shortcut helper behavior, subfolder fallback moves, and `New-odscex` library-id handling.

## 0.5.1

* Added `Connect-odscex -Cloud` support for Microsoft Graph Global, GCC, GCC High, DoD, and China endpoints.
* Added Graph endpoint selection for national clouds so API requests use the connected cloud's Microsoft Graph root endpoint.
* Added optional `-GraphEndpoint` override for advanced/custom national-cloud endpoint scenarios.
* Fixed shortcut creation with `-RelativePath` so shortcuts are created directly in the target OneDrive folder.
* Resolved PowerShell Script Analyzer warnings before publishing the release to PowerShell Gallery.

## 0.5.0

* Added organization-scale shortcut assignment commands: `Get-odscexTargetUser`, `Set-odscexShortcutState`, `Invoke-odscexShortcutAssignment`, `Invoke-odscexPlan`, `Invoke-odscexApply`, `Invoke-odscexGraphBatch`, and `Test-odscexPermission`.
* Added idempotent desired-state behavior with configurable conflict actions.
* Added Microsoft Graph retry/backoff handling, pagination support, and a JSON batch helper.
* Added safer OneDrive path encoding, folder-path resolution, and exact document-library matching with ambiguity protection.
* Added pipeline-friendly user parameters, structured shortcut result objects, and CSV/JSON/CLIXML report output.
* Improved module import style and bumped the module version to 0.5.0.

## 0.4.1

* Fixed a security warning in WindowsPowerShell triggered by `Invoke-WebRequest` calls missing the `-UseBasicParsing` parameter.

## 0.4.0

* Add feature to create / get / remove shortcuts in OneDrive's subfolder

## 0.3.0

* Change endpoint `/drives/{idOrUserPrincipalName}` to `/users/{idOrUserPrincipalName}/drive`
* New command: `Get-odscexDrive`
* Ease use in scripts by removing Stop on some errors
* Ensure that `Remove-odscex` removes a remoteItem-type resource
* Move token to global script variable for better interaction in scripts
* Other minor fixes and updates

## 0.2.1

* Add rename request to name shortcut exactly as passed to the script
* Change leading blank spaces to tabs
* Refactor from OneDriveShortcut to odscex. Commands now are: `Connect-odscex`, `Disconnect-odscex`, `Get-odscex`, `New-odscex`, `Remove-odscex`. API is `Invoke-odscexApiRequest`

## 0.1.1

*   Fixed issue [#1](https://github.com/derpenstiltskin/onedriveshortcuts/issues/1#issue-1504890237) by adding option to specify AzureCloudInstance when connecting

## 0.1.0

*   Initial release
*   Commands: `Connect-ODS`, `Disconnect-ODS`, `Get-OneDriveShortcut`, `New-OneDriveShortcut`, `Remove-OneDriveShortcut`
