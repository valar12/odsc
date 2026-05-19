BeforeAll {
    . "$PSScriptRoot/../src/private/ConvertTo-odscexGraphDrivePath.ps1"
    . "$PSScriptRoot/../src/private/Join-odscexDrivePathResource.ps1"
    . "$PSScriptRoot/../src/private/Write-odscexResult.ps1"
    . "$PSScriptRoot/../src/public/Remove-odscex.ps1"
}

Describe 'Remove-odscex' {
    It 'removes a shortcut from a OneDrive RelativePath folder' {
        $script:Requests = [System.Collections.Generic.List[object]]::new()

        function Invoke-odscexApiRequest {
            param(
                [string] $Resource,
                [Microsoft.PowerShell.Commands.WebRequestMethod] $Method
            )

            $script:Requests.Add([pscustomobject]@{ Resource = $Resource; Method = $Method }) | Out-Null

            if ($Resource -eq 'users/user@contoso.com/drive/root:/Shortcuts/2025-06-25' -and $Method -eq [Microsoft.PowerShell.Commands.WebRequestMethod]::Get) {
                return [pscustomobject]@{
                    id = 'existing-shortcut'
                    remoteItem = [pscustomobject]@{
                        sharepointIds = [pscustomobject]@{
                            listId = 'list'
                            listItemUniqueId = 'unique'
                        }
                    }
                }
            }

            if ($Resource -eq 'users/user@contoso.com/drive/root:/Shortcuts/2025-06-25' -and $Method -eq [Microsoft.PowerShell.Commands.WebRequestMethod]::Delete) {
                return $null
            }

            throw "Unexpected $Method $Resource"
        }

        Remove-odscex -ShortcutName '2025-06-25' -RelativePath 'Shortcuts' -UserPrincipalName 'user@contoso.com' -Confirm:$false | Out-Null

        $script:Requests | Should -HaveCount 2
        $script:Requests[0].Method | Should -Be ([Microsoft.PowerShell.Commands.WebRequestMethod]::Get)
        $script:Requests[0].Resource | Should -Be 'users/user@contoso.com/drive/root:/Shortcuts/2025-06-25'
        $script:Requests[1].Method | Should -Be ([Microsoft.PowerShell.Commands.WebRequestMethod]::Delete)
        $script:Requests[1].Resource | Should -Be 'users/user@contoso.com/drive/root:/Shortcuts/2025-06-25'
    }
}
