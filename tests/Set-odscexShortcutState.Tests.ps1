BeforeAll {
    . "$PSScriptRoot/../src/private/Get-odscexGraphStatusCode.ps1"
    . "$PSScriptRoot/../src/private/ConvertTo-odscexJsonBody.ps1"
    . "$PSScriptRoot/../src/private/Join-odscexDriveItemResource.ps1"
    . "$PSScriptRoot/../src/private/Join-odscexDrivePathResource.ps1"
    . "$PSScriptRoot/../src/private/Join-odscexDrivePathChildrenResource.ps1"
    . "$PSScriptRoot/../src/private/ConvertTo-odscexGraphDrivePath.ps1"
    . "$PSScriptRoot/../src/private/New-odscexRemoteItemReference.ps1"
    . "$PSScriptRoot/../src/private/Test-odscexShortcutTargetMatch.ps1"
    . "$PSScriptRoot/../src/private/Move-odscexDriveItemWithRetry.ps1"
    . "$PSScriptRoot/../src/private/Write-odscexResult.ps1"
    . "$PSScriptRoot/../src/public/Set-odscexShortcutState.ps1"
}

Describe 'shortcut helper functions' {
    It 'builds drive item resources for user and drive scoped calls' {
        Join-odscexDriveItemResource -User 'user@contoso.com' -ItemId 'item' | Should -Be 'users/user@contoso.com/drive/items/item'
        Join-odscexDriveItemResource -DriveId 'drive' -ItemId 'item' -Children | Should -Be 'drives/drive/items/item/children'
        Join-odscexDrivePathChildrenResource -User 'user@contoso.com' -RelativePath 'Shortcuts/Nested' | Should -Be 'users/user@contoso.com/drive/root:/Shortcuts/Nested:/children'
        Join-odscexDrivePathChildrenResource -DriveId 'drive' -RelativePath 'Shortcuts/Nested' | Should -Be 'drives/drive/root:/Shortcuts/Nested:/children'
    }

    It 'serializes object bodies while leaving raw JSON strings unchanged' {
        $Json = ConvertTo-odscexJsonBody -Body @{ name = 'Shortcut' }
        ($Json | ConvertFrom-Json).name | Should -Be 'Shortcut'
        ConvertTo-odscexJsonBody -Body '{"name":"Raw"}' | Should -Be '{"name":"Raw"}'
    }

    It 'matches shortcuts by SharePoint ids or drive item reference' {
        $SharePointTarget = [pscustomobject]@{
            ItemUniqueId = 'unique'
            DocumentLibraryId = 'list'
            SiteId = 'site'
            WebId = 'web'
        }
        $SharePointShortcut = [pscustomobject]@{
            remoteItem = [pscustomobject]@{
                sharepointIds = [pscustomobject]@{
                    listId = 'list'
                    listItemUniqueId = 'unique'
                    siteId = 'site'
                    webId = 'web'
                }
            }
        }
        Test-odscexShortcutTargetMatch -Shortcut $SharePointShortcut -Target $SharePointTarget | Should -BeTrue

        $DriveTarget = [pscustomobject]@{ DriveId = 'drive'; DriveItemId = 'item' }
        $DriveShortcut = [pscustomobject]@{
            remoteItem = [pscustomobject]@{
                id = 'item'
                parentReference = [pscustomobject]@{ driveId = 'drive' }
            }
        }
        Test-odscexShortcutTargetMatch -Shortcut $DriveShortcut -Target $DriveTarget | Should -BeTrue
    }

    It 'builds remoteItem references from SharePoint ids or drive item ids' {
        $SharePointRemoteItem = New-odscexRemoteItemReference -Target ([pscustomobject]@{
            ItemUniqueId = 'unique'
            DocumentLibraryId = 'list'
            SiteId = 'site'
            SiteUrl = 'https://contoso.sharepoint.com'
            WebId = 'web'
        })
        $SharePointRemoteItem.sharepointIds.listItemUniqueId | Should -Be 'unique'

        $DriveRemoteItem = New-odscexRemoteItemReference -Target ([pscustomobject]@{
            DriveId = 'drive'
            DriveItemId = 'item'
        })
        $DriveRemoteItem.id | Should -Be 'item'
        $DriveRemoteItem.parentReference.driveId | Should -Be 'drive'
    }
}

Describe 'Set-odscexShortcutState' {
    It 'retries moving a fallback-created shortcut before renaming when Graph rejects direct and path nested creation' {
        $script:Requests = [System.Collections.Generic.List[object]]::new()
        $script:MovePatchAttempts = 0
        $script:SleepSeconds = [System.Collections.Generic.List[int]]::new()

        function Resolve-odscexShortcutTarget {
            [pscustomobject]@{
                DefaultShortcutName = '2025-06-25'
                DriveId = 'target-drive'
                DriveItemId = 'target-item'
            }
        }

        function Resolve-odscexOneDriveRoot {
            [pscustomobject]@{
                id = 'root-item'
                parentReference = [pscustomobject]@{ driveId = 'user-drive' }
            }
        }

        function Resolve-odscexDriveFolderPath {
            [pscustomobject]@{
                id = 'destination-folder'
                parentReference = [pscustomobject]@{ driveId = 'user-drive' }
            }
        }

        function Start-Sleep {
            param([int] $Seconds)
            $script:SleepSeconds.Add($Seconds) | Out-Null
        }

        function Invoke-odscexApiRequest {
            param(
                [string] $Resource,
                [Microsoft.PowerShell.Commands.WebRequestMethod] $Method,
                [object] $Body
            )

            $script:Requests.Add([pscustomobject]@{ Resource = $Resource; Method = $Method; Body = (ConvertTo-odscexJsonBody -Body $Body) }) | Out-Null

            if ($Resource -eq 'users/user@contoso.com/drive/root:/Shortcuts/2025-06-25' -and $Method -eq [Microsoft.PowerShell.Commands.WebRequestMethod]::Get) {
                throw 'StatusCode: 404'
            }

            if ($Resource -eq 'drives/user-drive/items/destination-folder/children' -and $Method -eq [Microsoft.PowerShell.Commands.WebRequestMethod]::Post) {
                throw 'StatusCode: 400'
            }

            if ($Resource -eq 'drives/user-drive/root:/Shortcuts:/children' -and $Method -eq [Microsoft.PowerShell.Commands.WebRequestMethod]::Post) {
                throw 'StatusCode: 400'
            }

            if ($Resource -eq 'drives/user-drive/items/root-item/children' -and $Method -eq [Microsoft.PowerShell.Commands.WebRequestMethod]::Post) {
                return [pscustomobject]@{ id = 'temporary-shortcut' }
            }

            if ($Resource -eq 'drives/user-drive/items/temporary-shortcut' -and $Method -eq [Microsoft.PowerShell.Commands.WebRequestMethod]::Patch) {
                $RequestBody = ConvertTo-odscexJsonBody -Body $Body | ConvertFrom-Json
                if ($RequestBody.parentReference) {
                    $script:MovePatchAttempts++
                    if ($script:MovePatchAttempts -lt 3) {
                        throw 'StatusCode: 400'
                    }
                }

                return [pscustomobject]@{ id = 'temporary-shortcut' }
            }
        }

        Set-odscexShortcutState -Uri 'https://contoso.sharepoint.com' -DocumentLibrary 'Documents' -FolderPath '2025-06-25' -RelativePath 'Shortcuts' -UserPrincipalName 'user@contoso.com' -Confirm:$false | Out-Null

        $PatchRequests = @($script:Requests | Where-Object { $_.Method -eq [Microsoft.PowerShell.Commands.WebRequestMethod]::Patch })
        $PatchRequests | Should -HaveCount 4
        $script:SleepSeconds.ToArray() | Should -Be @(2, 4)

        $MoveRequests = @($PatchRequests | Select-Object -First 3)
        foreach ($MoveRequest in $MoveRequests) {
            $MoveRequest.Resource | Should -Be 'drives/user-drive/items/temporary-shortcut'
            $MoveBody = $MoveRequest.Body | ConvertFrom-Json
            $MoveBody.parentReference.id | Should -Be 'destination-folder'
            $MoveBody.parentReference.driveId | Should -Be 'user-drive'
            $MoveBody.PSObject.Properties.Name | Should -Not -Contain 'name'
        }

        $PatchRequests[3].Resource | Should -Be 'drives/user-drive/items/temporary-shortcut'
        $RenameBody = $PatchRequests[3].Body | ConvertFrom-Json
        $RenameBody.name | Should -Be '2025-06-25'
        $RenameBody.PSObject.Properties.Name | Should -Not -Contain 'parentReference'
    }

    It 'creates in the RelativePath folder by path when item-id creation returns 400' {
        $script:Requests = [System.Collections.Generic.List[object]]::new()

        function Resolve-odscexShortcutTarget {
            [pscustomobject]@{
                DefaultShortcutName = '2025-06-25'
                DriveId = 'target-drive'
                DriveItemId = 'target-item'
            }
        }

        function Resolve-odscexOneDriveRoot {
            [pscustomobject]@{
                id = 'root-item'
                parentReference = [pscustomobject]@{ driveId = 'user-drive' }
            }
        }

        function Resolve-odscexDriveFolderPath {
            [pscustomobject]@{
                id = 'destination-folder'
                parentReference = [pscustomobject]@{ driveId = 'user-drive' }
            }
        }

        function Invoke-odscexApiRequest {
            param(
                [string] $Resource,
                [Microsoft.PowerShell.Commands.WebRequestMethod] $Method,
                [object] $Body
            )

            $script:Requests.Add([pscustomobject]@{ Resource = $Resource; Method = $Method; Body = (ConvertTo-odscexJsonBody -Body $Body) }) | Out-Null

            if ($Resource -eq 'users/user@contoso.com/drive/root:/Shortcuts/2025-06-25' -and $Method -eq [Microsoft.PowerShell.Commands.WebRequestMethod]::Get) {
                throw 'StatusCode: 404'
            }

            if ($Resource -eq 'drives/user-drive/items/destination-folder/children' -and $Method -eq [Microsoft.PowerShell.Commands.WebRequestMethod]::Post) {
                throw 'StatusCode: 400'
            }

            if ($Resource -eq 'drives/user-drive/root:/Shortcuts:/children' -and $Method -eq [Microsoft.PowerShell.Commands.WebRequestMethod]::Post) {
                return [pscustomobject]@{ id = 'created-in-folder' }
            }

            if ($Resource -eq 'drives/user-drive/items/created-in-folder' -and $Method -eq [Microsoft.PowerShell.Commands.WebRequestMethod]::Patch) {
                return [pscustomobject]@{ id = 'created-in-folder'; name = '2025-06-25' }
            }
        }

        Set-odscexShortcutState -Uri 'https://contoso.sharepoint.com' -DocumentLibrary 'Documents' -FolderPath '2025-06-25' -RelativePath 'Shortcuts' -UserPrincipalName 'user@contoso.com' -Confirm:$false | Out-Null

        $PostResources = @($script:Requests | Where-Object { $_.Method -eq [Microsoft.PowerShell.Commands.WebRequestMethod]::Post } | Select-Object -ExpandProperty Resource)
        $PostResources | Should -Contain 'drives/user-drive/items/destination-folder/children'
        $PostResources | Should -Contain 'drives/user-drive/root:/Shortcuts:/children'
        $PostResources | Should -Not -Contain 'drives/user-drive/items/root-item/children'

        $PatchRequests = @($script:Requests | Where-Object { $_.Method -eq [Microsoft.PowerShell.Commands.WebRequestMethod]::Patch })
        $PatchRequests | Should -HaveCount 1
        $PatchRequests[0].Resource | Should -Be 'drives/user-drive/items/created-in-folder'
        ($PatchRequests[0].Body | ConvertFrom-Json).name | Should -Be '2025-06-25'
    }
}
