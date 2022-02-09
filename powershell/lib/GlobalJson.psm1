function ReformatJson {
param( [string] $source = $(throw "ReformatJson: source not specified")
    )
    
    $obj = $source | ConvertFrom-Json
    
    [string] $reformatted = $obj | ConvertTo-Json -Compress
    
    return $reformatted
}

function ReformatJsonForSaving {
param( [string] $source = $(throw "ReformatJson: source not specified")
    )
    
    $obj = $source | ConvertFrom-Json
    
    [string] $reformatted = $obj | ConvertTo-Json
    
    return $reformatted
}

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
        [String] $sourceFileName = $(throw "GlobalJson_Update: sourceFileName not specified"),
        [String] $targetFileName = $(throw "GlobalJson_Update: targetFileName not specified")
    )
    
    [string] $targetFreezeFileName = $targetFileName + ".freeze"
    [bool]$trgFreezeExists = Test-Path -Path $targetFreezeFileName
    if ($trgFreezeExists -eq $true) {
        # no source to update
        Write-Information "* no global.json is frozen in target"
        return [pscustomobject]@{
            Update = $false
            UpdatingVersion = $false
            NewVersion = $null
        }
    }

    [bool]$srcExists = Test-Path -Path $sourceFileName
    if ($srcExists -eq $false) {
        # no source to update
        Write-Information "* no global.json in template"

        return [pscustomobject]@{
            Update = $false
            UpdatingVersion = $false
            NewVersion = $null
        }
    }

    [string]$srcContent = Get-Content -Path $sourceFileName -Raw        
    $srcGlobal = $srcContent | ConvertFrom-Json

    [bool]$trgExists = Test-Path -Path $targetFileName
    if ($trgExists -ne $true) {
        Write-Information "Target global.json does not exist: creating"

        $reformatted = ReformatJsonForSaving -source $srcContent 
        Set-Content -Path $targetFileName -Value $reformatted 
    
        return [pscustomobject]@{
            Update = $true
            UpdatingVersion = $false
            NewVersion = $null
        }   
    }

    [string]$trgContent = Get-Content -Path $targetFileName -Raw
    
    # Ensure that the Json files are reformatted the same way for any comparisons
    [string]$srcContent = ReformatJson -source $srcContent
    [string]$trgContent = ReformatJson -source $trgContent

    if ($srcContent -eq $trgContent) {
        Write-Information "* target global.json same as source"
        
        return [pscustomobject]@{
            Update = $false
            UpdatingVersion = $false
            NewVersion = $null
        }
    }

    $trgGlobal = $trgContent | ConvertFrom-Json

    [string]$sourceVersion = $srcGlobal.sdk.version
    [string]$targetVersion = $trgGlobal.sdk.version
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

        $reformatted = ReformatJsonForSaving -source $srcContent 
        Set-Content -Path $targetFileName -Value $reformatted 

        return [pscustomobject]@{
            Update = $true
            UpdatingVersion = $true
            NewVersion = $sourceVersion
        }
    }
    
    Write-Information "* Target global.json different but not by version"
    $reformatted = ReformatJsonForSaving -source $srcContent 
    Set-Content -Path $targetFileName -Value $reformatted 

    return [pscustomobject]@{
        Update = $true
        UpdatingVersion = $false
        NewVersion = $null
    }
}

Export-ModuleMember -Function GlobalJson_Update