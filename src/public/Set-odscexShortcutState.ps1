function Set-odscexShortcutState {
    [CmdletBinding(DefaultParameterSetName = 'UserPrincipalName', SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'UserPrincipalName')]
        [Parameter(Mandatory = $true, ParameterSetName = 'UserObjectId')]
        [string] $Uri,

        [Parameter(Mandatory = $false, ParameterSetName = 'UserPrincipalName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'UserObjectId')]
        [string] $DocumentLibrary,

        [Parameter(Mandatory = $false, ParameterSetName = 'UserPrincipalName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'UserObjectId')]
        [string] $DocumentLibraryId,

        [Parameter(Mandatory = $false, ParameterSetName = 'UserPrincipalName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'UserObjectId')]
        [string] $FolderPath,

        [Parameter(Mandatory = $false, ParameterSetName = 'UserPrincipalName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'UserObjectId')]
        [string] $RelativePath,

        [Parameter(Mandatory = $false, ParameterSetName = 'UserPrincipalName')]
        [Parameter(Mandatory = $false, ParameterSetName = 'UserObjectId')]
        [string] $ShortcutName,

        [Parameter(Mandatory = $true, ParameterSetName = 'UserPrincipalName', ValueFromPipelineByPropertyName = $true)]
        [Alias('Mail')]
        [string] $UserPrincipalName,

        [Parameter(Mandatory = $true, ParameterSetName = 'UserObjectId', ValueFromPipelineByPropertyName = $true)]
        [Alias('Id', 'UserId')]
        [string] $UserObjectId,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Present', 'Absent')]
        [string] $State = 'Present',

        [Parameter(Mandatory = $false)]
        [ValidateSet('Skip', 'Replace', 'Rename', 'Error')]
        [string] $ConflictAction = 'Skip',

        [Parameter(Mandatory = $false)]
        [switch] $AllowAmbiguousLibraryMatch,

        [Parameter(Mandatory = $false)]
        [switch] $PassThru
    )

    process {
        if (-not $DocumentLibrary -and -not $DocumentLibraryId) {
            Write-Error 'Specify -DocumentLibrary or -DocumentLibraryId.' -ErrorAction Stop
        }

        $User = switch ($PsCmdlet.ParameterSetName) {
            'UserPrincipalName' { $UserPrincipalName }
            'UserObjectId' { $UserObjectId }
        }

        $Target = Resolve-odscexShortcutTarget -Uri $Uri -DocumentLibrary $DocumentLibrary -DocumentLibraryId $DocumentLibraryId -FolderPath $FolderPath -AllowAmbiguousLibraryMatch:$AllowAmbiguousLibraryMatch
        if (-not $ShortcutName) {
            $ShortcutName = $Target.DefaultShortcutName
        }

        $ShortcutResource = Join-odscexDrivePathResource -User $User -RelativePath $RelativePath -Name $ShortcutName
        $ExistingShortcut = $null
        try {
            $ExistingShortcut = Invoke-odscexApiRequest -Resource $ShortcutResource -Method ([Microsoft.PowerShell.Commands.WebRequestMethod]::Get) -ErrorAction Stop
        } catch {
            $StatusCode = Get-odscexGraphStatusCode -ErrorRecord $_
            if ($StatusCode -eq 404) {
                $ExistingShortcut = $null
            } elseif ($StatusCode -eq 403) {
                Write-Error "Unable to check for existing shortcut '$ShortcutName' for '$User'. Microsoft Graph returned 403 for $ShortcutResource. Verify permission to read the user's OneDrive." -ErrorAction Stop
            } else {
                Write-Error "Unable to check for existing shortcut '$ShortcutName' for '$User'. $($_.Exception.Message)" -ErrorAction Stop
            }
        }

        if ($State -eq 'Absent') {
            if (-not $ExistingShortcut) {
                return Write-odscexResult -User $User -ShortcutName $ShortcutName -Action 'Remove' -Status 'AlreadyAbsent' -Message 'Shortcut was already absent.' -TargetSite $Uri -TargetLibrary $DocumentLibrary -TargetFolderPath $FolderPath
            }

            if (-not $ExistingShortcut.remoteItem) {
                Write-Error "Existing item '$ShortcutName' for '$User' is not a OneDrive shortcut." -ErrorAction Stop
            }

            if ($PSCmdlet.ShouldProcess("${User}'s OneDrive", "Removing shortcut '$ShortcutName'")) {
                Invoke-odscexApiRequest -Resource $ShortcutResource -Method ([Microsoft.PowerShell.Commands.WebRequestMethod]::Delete) | Out-Null
                return Write-odscexResult -User $User -ShortcutName $ShortcutName -Action 'Remove' -Status 'Removed' -Response $ExistingShortcut -TargetSite $Uri -TargetLibrary $DocumentLibrary -TargetFolderPath $FolderPath
            }

            return
        }

        if ($ExistingShortcut) {
            if (Test-odscexShortcutTargetMatch -Shortcut $ExistingShortcut -Target $Target) {
                return Write-odscexResult -User $User -ShortcutName $ShortcutName -Action 'None' -Status 'Compliant' -Response $ExistingShortcut -Message 'Shortcut already points to the requested target.' -TargetSite $Uri -TargetLibrary $DocumentLibrary -TargetFolderPath $FolderPath
            }

            switch ($ConflictAction) {
                'Skip' {
                    return Write-odscexResult -User $User -ShortcutName $ShortcutName -Action 'None' -Status 'SkippedConflict' -Response $ExistingShortcut -Message 'An item with the requested shortcut name already exists.' -TargetSite $Uri -TargetLibrary $DocumentLibrary -TargetFolderPath $FolderPath
                }
                'Error' {
                    Write-Error "An item named '$ShortcutName' already exists for '$User' and does not match the requested target." -ErrorAction Stop
                }
                'Replace' {
                    if ($PSCmdlet.ShouldProcess("${User}'s OneDrive", "Replacing shortcut '$ShortcutName'")) {
                        Invoke-odscexApiRequest -Resource $ShortcutResource -Method ([Microsoft.PowerShell.Commands.WebRequestMethod]::Delete) | Out-Null
                        $ExistingShortcut = $null
                    } else {
                        return
                    }
                }
                'Rename' {
                    $ShortcutName = "$ShortcutName-$([DateTime]::UtcNow.ToString('yyyyMMddHHmmss'))"
                    $ShortcutResource = Join-odscexDrivePathResource -User $User -RelativePath $RelativePath -Name $ShortcutName
                }
            }
        }

        $OneDriveRoot = Resolve-odscexOneDriveRoot -User $User

        $RemoteItem = New-odscexRemoteItemReference -Target $Target -ShortcutName $ShortcutName

        $OneDriveDriveId = $OneDriveRoot.parentReference.driveId
        # Prefer drive-scoped item URLs after the destination drive is known. Microsoft Graph can
        # reject remoteItem create/move requests that are routed through /users/{id}/drive.
        $RootCreateResource = if ($OneDriveDriveId) {
            Join-odscexDriveItemResource -DriveId $OneDriveDriveId -ItemId $OneDriveRoot.id -Children
        } else {
            Join-odscexDriveItemResource -User $User -ItemId $OneDriveRoot.id -Children
        }
        $CreateRequest = @{
            Resource = $RootCreateResource
            Method = [Microsoft.PowerShell.Commands.WebRequestMethod]::Post
            Body = @{
                name = $ShortcutName
                remoteItem = $RemoteItem
                '@microsoft.graph.conflictBehavior' = if ($ConflictAction -eq 'Rename') { 'rename' } else { 'fail' }
            }
        }

        if ($PSCmdlet.ShouldProcess("${User}'s OneDrive", "Creating shortcut '$ShortcutName'")) {
            $DestinationFolder = $null
            $DestinationDriveId = $null
            $MoveShortcutToDestination = $false
            if ($RelativePath) {
                $FolderResponse = Resolve-odscexDriveFolderPath -User $User -RelativePath $RelativePath -Create
                if (-not $FolderResponse) {
                    Write-Error "Error resolving OneDrive folder path '$RelativePath' for ${User}." -ErrorAction Stop
                }

                $DestinationFolder = $FolderResponse
                $DestinationDriveId = $DestinationFolder.parentReference.driveId
                if (-not $DestinationDriveId) {
                    $DestinationDriveId = $OneDriveDriveId
                }

                $CreateRequest.Resource = if ($DestinationDriveId) {
                    Join-odscexDriveItemResource -DriveId $DestinationDriveId -ItemId $FolderResponse.id -Children
                } else {
                    Join-odscexDriveItemResource -User $User -ItemId $FolderResponse.id -Children
                }
            }

            try {
                $ShortcutResponse = Invoke-odscexApiRequest @CreateRequest -ErrorAction Stop
            } catch {
                $StatusCode = Get-odscexGraphStatusCode -ErrorRecord $_
                if (($StatusCode -ne 400) -or (-not $DestinationFolder)) {
                    Write-Error $_ -ErrorAction Stop
                }

                $PathCreateResource = if ($DestinationDriveId) {
                    Join-odscexDrivePathChildrenResource -DriveId $DestinationDriveId -RelativePath $RelativePath
                } else {
                    Join-odscexDrivePathChildrenResource -User $User -RelativePath $RelativePath
                }

                Write-Verbose "Microsoft Graph rejected shortcut creation by destination item id inside '$RelativePath'. Retrying with the destination folder path resource."
                $CreateRequest.Resource = $PathCreateResource
                try {
                    $ShortcutResponse = Invoke-odscexApiRequest @CreateRequest -ErrorAction Stop
                } catch {
                    $PathStatusCode = Get-odscexGraphStatusCode -ErrorRecord $_
                    if ($PathStatusCode -ne 400) {
                        Write-Error $_ -ErrorAction Stop
                    }

                    Write-Verbose "Microsoft Graph also rejected shortcut creation by destination path inside '$RelativePath'. Creating the shortcut at the OneDrive root, then moving it to the requested folder."
                    $TemporaryShortcutName = "_odscex-$([Guid]::NewGuid().ToString('N'))"
                    $CreateRequest.Resource = $RootCreateResource
                    $CreateRequest.Body = @{
                        name = $TemporaryShortcutName
                        remoteItem = $RemoteItem
                        '@microsoft.graph.conflictBehavior' = 'fail'
                    }

                    $ShortcutResponse = Invoke-odscexApiRequest @CreateRequest
                    $MoveShortcutToDestination = $true
                }
            }

            if (!($ShortcutResponse)) {
                Write-Error "Error creating OneDrive shortcut '$($ShortcutName)' for ${User}." -ErrorAction Stop
            }

            try {
                if ($MoveShortcutToDestination) {
                    $ShortcutMoveResources = [System.Collections.Generic.List[string]]::new()
                    if ($OneDriveDriveId) {
                        $ShortcutMoveResources.Add((Join-odscexDriveItemResource -DriveId $OneDriveDriveId -ItemId $ShortcutResponse.id)) | Out-Null
                    }

                    if ($DestinationDriveId -and ($DestinationDriveId -ne $OneDriveDriveId)) {
                        $ShortcutMoveResources.Add((Join-odscexDriveItemResource -DriveId $DestinationDriveId -ItemId $ShortcutResponse.id)) | Out-Null
                    }

                    $ShortcutMoveResources.Add((Join-odscexDriveItemResource -User $User -ItemId $ShortcutResponse.id)) | Out-Null
                    $ShortcutResourceById = $ShortcutMoveResources[0]

                    $ShortcutResponse = Move-odscexDriveItemWithRetry `
                        -Resource $ShortcutMoveResources.ToArray() `
                        -DestinationFolderId $DestinationFolder.id `
                        -DestinationDriveId $DestinationDriveId `
                        -RelativePath $RelativePath `
                        -ShortcutName $ShortcutName `
                        -ItemId $ShortcutResponse.id
                }

                $ShortcutResourceById = if ($DestinationDriveId) {
                    Join-odscexDriveItemResource -DriveId $DestinationDriveId -ItemId $ShortcutResponse.id
                } elseif ($OneDriveDriveId) {
                    Join-odscexDriveItemResource -DriveId $OneDriveDriveId -ItemId $ShortcutResponse.id
                } else {
                    Join-odscexDriveItemResource -User $User -ItemId $ShortcutResponse.id
                }

                $RenameRequest = @{
                    Resource = $ShortcutResourceById
                    Method = [Microsoft.PowerShell.Commands.WebRequestMethod]::Patch
                    Body = @{ name = $ShortcutName }
                }
                $ShortcutResponse = Invoke-odscexApiRequest @RenameRequest -ErrorAction Stop
            } catch {
                if ($MoveShortcutToDestination) {
                    try {
                        Invoke-odscexApiRequest -Resource $ShortcutResourceById -Method ([Microsoft.PowerShell.Commands.WebRequestMethod]::Delete) -ErrorAction Stop | Out-Null
                    } catch {
                        Write-Verbose "Unable to clean up temporary shortcut '$($ShortcutResponse.id)' after fallback move or rename failure. $($_.Exception.Message)"
                    }
                }

                Write-Error $_ -ErrorAction Stop
            }

            if ($PassThru) {
                return $ShortcutResponse
            }

            return Write-odscexResult -User $User -ShortcutName $ShortcutName -Action 'Create' -Status 'Created' -Response $ShortcutResponse -TargetSite $Uri -TargetLibrary $DocumentLibrary -TargetFolderPath $FolderPath
        }
    }
}
