function Tracking_Read {
param (
    [string] $fileName = $(throw "fileName not specified")
    )

    $content = @{}

    [string]$srcExists = Test-Path -Path $fileName
    if($srcExists -eq $true) {

        $obj = Get-Content -Path $srcPath| Out-String | ConvertFrom-Json

        $obj.psobject.properties | Foreach { $content[$_.Name] = $_.Value }
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
    [string] $basePath = $(throw "basePath not specified"), 
    [string] $repo = $(throw "repo not specified")
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
    [string] $basePath = $(throw "basePath not specified"), 
    [string] $repo = $(throw "repo not specified"),
    [string] $value = $(throw "value not specified")
    )

    [string]$srcPath = Join-Path -Path $basePath -ChildPath "tracking.json"

    $content = Tracking_Read -fileName $srcPath

    $content[$repo] = $value;

    $fileContent = $content | ConvertTo-Json

    Set-Content -Path $srcPath -Value $fileContent
}


Export-ModuleMember -Function Tracking_Get
Export-ModuleMember -Function Tracking_Set