<#
 .Synopsis
  Updates the global.json file

 .Description
  Updates the global.json file

 .Parameter sourceFileName
  The source filename
 .Parameter targetFileName
  The file to write
#>
function GlobalJson_Update
{
    param(
        [String] $sourceFileName,
        [String] $targetFileName
    )
    $targetFreezeFileName = $targetFileName + ".freeze"
    $trgFreezeExists = Test-Path -Path $targetFreezeFileName
    if ($trgFreezeExists -eq $true) {
        # no source to update
        Write-Information "* no global.json is frozen in target"
        return [pscustomobject]@{
            Update = $false
            UpdatingVersion = $false
            NewVersion = $null
        }
    }

    $srcExists = Test-Path -Path $sourceFileName
    if ($srcExists -eq $false) {
        # no source to update
        Write-Information "* no global.json in template"

        return [pscustomobject]@{
            Update = $false
            UpdatingVersion = $false
            NewVersion = $null
        }
    }

    $srcContent = Get-Content -Path $sourceFileName -Raw
    $srcGlobal = $srcContent | ConvertFrom-Json

    $trgExists = Test-Path -Path $targetFileName
    if ($trgExists -ne $true) {
        Write-Information "Target global.json does not exist: creating"

        Set-Content -Path $targetFileName -Value $srcContent
    
        return [pscustomobject]@{
            Update = $true
            UpdatingVersion = $false
            NewVersion = $null
        }   
    }

    $trgContent = Get-Content -Path $targetFileName -Raw

    if ($srcContent -eq $trgContent)
    {
        Write-Information "* target global.json same as source"
        
        return [pscustomobject]@{
            Update = $false
            UpdatingVersion = $false
            NewVersion = $null
        }
    }

    $trgGlobal = $trgContent | ConvertFrom-Json

    $sourceVersion = $srcGlobal.sdk.version
    $targetVersion = $trgGlobal.sdk.version
    Write-Information "Source Version: $sourceVersion"
    Write-Information "Target Version: $targetVersion"

    if ($targetVersion -gt $sourceVersion) {
        Write-Information "* Target global.json specifies a newer version of .net ($targetVersion > $sourceVersion)"
        
        return [pscustomobject]@{
            Update = $false
            UpdatingVersion = $false
            NewVersion = $null
        }
    }

    if ($targetVersion -lt $sourceVersion) {
        Write-Information "* Target global.json specifies a older version of .net ($targetVersion) < $sourceVersion)"

        Set-Content -Path $targetFileName -Value $srcContent

        return [pscustomobject]@{
            Update = $true
            UpdatingVersion = $true
            NewVersion = $sourceVersion
        }
    }
    
    Write-Information "* Target global.json different but not by version"
    Set-Content -Path $targetFileName -Value $srcContent

    return [pscustomobject]@{
        Update = $true
        UpdatingVersion = $false
        NewVersion = $null
    }
}

Export-ModuleMember -Function GlobalJson_Update