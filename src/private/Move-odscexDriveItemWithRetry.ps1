function Move-odscexDriveItemWithRetry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]] $Resource,

        [Parameter(Mandatory = $true)]
        [string] $DestinationFolderId,

        [Parameter(Mandatory = $false)]
        [string] $DestinationDriveId,

        [Parameter(Mandatory = $false)]
        [string] $RelativePath,

        [Parameter(Mandatory = $false)]
        [string] $ShortcutName,

        [Parameter(Mandatory = $false)]
        [string] $ItemId,

        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 10)]
        [int] $MaxRetryCount = 5
    )

    $ParentReferences = [System.Collections.Generic.List[object]]::new()
    $ParentReference = @{
        id = $DestinationFolderId
    }

    if ($DestinationDriveId) {
        $ParentReference.driveId = $DestinationDriveId
    }

    $ParentReferences.Add([pscustomobject]@{
        Description = if ($DestinationDriveId) { 'destination folder id and drive id' } else { 'destination folder id' }
        Value = $ParentReference
    }) | Out-Null

    if ($DestinationDriveId) {
        $ParentReferences.Add([pscustomobject]@{
            Description = 'destination folder id only'
            Value = @{ id = $DestinationFolderId }
        }) | Out-Null
    }

    $EncodedRelativePath = ConvertTo-odscexGraphDrivePath -Path $RelativePath
    if (-not [string]::IsNullOrWhiteSpace($EncodedRelativePath)) {
        $PathReference = @{
            path = "/drive/root:/$EncodedRelativePath"
        }

        if ($DestinationDriveId) {
            $PathReference.driveId = $DestinationDriveId
        }

        $ParentReferences.Add([pscustomobject]@{
            Description = if ($DestinationDriveId) { 'destination folder path and drive id' } else { 'destination folder path' }
            Value = $PathReference
        }) | Out-Null
    }

    $MoveBodies = [System.Collections.Generic.List[object]]::new()
    if (-not [string]::IsNullOrWhiteSpace($ShortcutName)) {
        foreach ($Reference in $ParentReferences) {
            $MoveBodies.Add([pscustomobject]@{
                Description = "$($Reference.Description) with final shortcut name"
                Value = @{
                    parentReference = $Reference.Value
                    name = $ShortcutName
                }
            }) | Out-Null
        }
    }

    foreach ($Reference in $ParentReferences) {
        $MoveBodies.Add([pscustomobject]@{
            Description = $Reference.Description
            Value = @{
                parentReference = $Reference.Value
            }
        }) | Out-Null
    }

    $MoveAttempt = 0
    while ($true) {
        foreach ($MoveResource in $Resource) {
            foreach ($MoveBody in $MoveBodies) {
                $MoveRequest = @{
                    Resource = $MoveResource
                    Method = [Microsoft.PowerShell.Commands.WebRequestMethod]::Patch
                    DoNotUsePrefer = $true
                    Body = $MoveBody.Value
                }

                try {
                    Write-Verbose "Moving newly created shortcut '$ItemId' into '$RelativePath' using $($MoveBody.Description) at '$MoveResource'."
                    return Invoke-odscexApiRequest @MoveRequest -ErrorAction Stop
                } catch {
                    $StatusCode = Get-odscexGraphStatusCode -ErrorRecord $_
                    if ($StatusCode -eq 400) {
                        Write-Verbose "Microsoft Graph returned HTTP 400 while moving newly created shortcut '$ItemId' into '$RelativePath' using $($MoveBody.Description) at '$MoveResource'."
                        continue
                    }

                    Write-Error $_ -ErrorAction Stop
                }
            }
        }

        $MoveAttempt++
        if ($MoveAttempt -le $MaxRetryCount) {
            $Delay = [Math]::Min(30, [int](2 * [Math]::Pow(2, ($MoveAttempt - 1))))
            Write-Verbose "Microsoft Graph rejected all shortcut move request shapes for '$ItemId' into '$RelativePath'. Retrying in $Delay seconds because OneDrive can take time to make a new shortcut movable."
            Start-Sleep -Seconds $Delay
            continue
        }

        Write-Error "Microsoft Graph rejected all shortcut move request shapes for '$ItemId' into '$RelativePath'." -ErrorAction Stop
    }
}
