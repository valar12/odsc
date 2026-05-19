function Move-odscexDriveItemWithRetry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Resource,

        [Parameter(Mandatory = $true)]
        [string] $DestinationFolderId,

        [Parameter(Mandatory = $false)]
        [string] $DestinationDriveId,

        [Parameter(Mandatory = $false)]
        [string] $RelativePath,

        [Parameter(Mandatory = $false)]
        [string] $ItemId,

        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 10)]
        [int] $MaxRetryCount = 5
    )

    $ParentReference = @{
        id = $DestinationFolderId
    }

    if ($DestinationDriveId) {
        $ParentReference.driveId = $DestinationDriveId
    }

    $MoveRequest = @{
        Resource = $Resource
        Method = [Microsoft.PowerShell.Commands.WebRequestMethod]::Patch
        Body = @{
            parentReference = $ParentReference
        }
    }

    $MoveAttempt = 0
    while ($true) {
        try {
            return Invoke-odscexApiRequest @MoveRequest -ErrorAction Stop
        } catch {
            $MoveAttempt++
            $StatusCode = Get-odscexGraphStatusCode -ErrorRecord $_
            if (($StatusCode -eq 400) -and ($MoveAttempt -le $MaxRetryCount)) {
                $Delay = [Math]::Min(30, [int](2 * [Math]::Pow(2, ($MoveAttempt - 1))))
                Write-Verbose "Microsoft Graph returned HTTP 400 while moving newly created shortcut '$ItemId' into '$RelativePath'. Retrying in $Delay seconds because OneDrive can take time to make a new shortcut movable."
                Start-Sleep -Seconds $Delay
                continue
            }

            Write-Error $_ -ErrorAction Stop
        }
    }
}
