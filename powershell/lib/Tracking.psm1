function Tracking_Read {
param (
    [string] $fileName = $(throw "Tracking_Read: fileName not specified")
    )
    
    Log -message "Tracking_Read: $fileName"

    $content = @{}

    [string]$srcExists = Test-Path -Path $fileName
    if($srcExists -eq $true) {
        $content = Get-Content -Path $srcPath | Out-String
        Log -message "Tracking_Read: $content"
        
        $obj = $content | ConvertFrom-Json
        Log -message "Tracking_Read: $obj"

        $obj.psobject.properties | ForEach { $content[$_.Name] = $_.Value }
    }
    else 
    {
        Log -message "Tracking_Read: $fileName does not exist"
    }

    return $content
}

<#
 .Synopsis
  Gets a setting from the tracking file.

 .Description
  Gets a setting from the tracking file.

 .Parameter basePath
  Location of the folder where the tracking file resides
 .Parameter repo
  The repo to get the setting for
#>
function Tracking_Get {
param(
    [string] $basePath = $(throw "Tracking_Get: basePath not specified"), 
    [string] $repo = $(throw "Tracking_Get: repo not specified")
    )

    [string]$srcPath = Join-Path -Path $basePath -ChildPath "tracking.json"

    $content = Tracking_Read -fileName $srcPath

    if($content.Contains($repo) -eq $true) {
        return $content[$repo]
    }
        
    return $null
}

<#
 .Synopsis
  Sets a setting in the tracking file.

 .Description
  Gets a setting from the tracking file.

 .Parameter basePath
  Location of the folder where the tracking file resides
 .Parameter repo
  The repo to set the setting for
 .Parameter value
  The new value to set
#>

function Tracking_Set {
param(
    [string] $basePath = $(throw "Tracking_Set: basePath not specified"), 
    [string] $repo = $(throw "Tracking_Set: repo not specified"),
    [string] $value = $(throw "Tracking_Set: value not specified")
    )

    [string]$srcPath = Join-Path -Path $basePath -ChildPath "tracking.json"

    $content = Tracking_Read -fileName $srcPath

    $content[$repo] = $value;

    $fileContent = $content | ConvertTo-Json

    Set-Content -Path $srcPath -Value $fileContent
}


Export-ModuleMember -Function Tracking_Get
Export-ModuleMember -Function Tracking_Set