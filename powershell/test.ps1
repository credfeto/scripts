Set-StrictMode -Version 1

Remove-Module *

$InformationPreference = "Continue"
$ErrorActionPreference = "Stop"
[bool]$preRelease = $False

# region Include required files
#
[string]$ScriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
[string]$ScriptDirectory = Join-Path -Path $ScriptDirectory -ChildPath "lib"
try {
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "DotNetTool.psm1") -Force -DisableNameChecking
}
catch {
    Write-Error $Error[0]
    Throw "Error while loading supporting PowerShell Scripts: DotNetTool"
}

try {
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "GitUtils.psm1") -Force -DisableNameChecking
}
catch {
    Write-Error $Error[0]
    Throw "Error while loading supporting PowerShell Scripts: GitUtils"
}

try {
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "DotNetPackages.psm1") -Force -DisableNameChecking
}
catch {
    Write-Error $Error[0]
    Throw "Error while loading supporting PowerShell Scripts: DotNetPackages"
}

#[bool]$installed = DotNetTool-Install -packageId "Credfeto.Changelog.Cmd" -preReleaseVersion $preRelease
#Write-Host "Installed: $installed"

#if($installed -eq $false) {
#    Write-Error ""
#    Write-Error "#teamcity[buildStatus status='FAILURE' text='Failed to install Credfeto.Changelog.Cmd']"
#}

# $changelog = "/data/work/funfair/funfair-server-code-analysis/CHANGELOG.md"
# 
# $file = Get-Content -Path $changelog
# 
# # Write-Host $file
# 
# $expr = "(?ms)" + "^\s*\-\s*FF\-1429\s*\-\sUpdated\s+(?<PackageId>.+(\.+)*?)\sto\s+(\d+\..*)$"
# foreach($line in $file) {
# 
#     $m = $line -match $expr
#     if($m) {    
#         Write-Host $matches.PackageId
#     }
# }

#$unixTime = git log -1 --format=%ct

#[DateTime]$when = [DateTimeOffset]::FromUnixTimeSeconds($unixTime).UtcDateTime
#[DateTime]$now = $now = [DateTime]::UtcNow

#[TimeSpan]$difference = $now - $when
#[double]$duration = $difference.TotalHours 

#Write-Host $when
#Write-Host $now

#Write-Host $duration

function ShouldUpdatePackage{
param (
    $installed,
    [string]$packageId,
    [bool]$exactMatch
)

    foreach($candidate in $installed) {
        if($packageId -eq $candidate) {
            return $true
        }

        if(!$exactMatch) {
            $test = "$packageId.".ToLower()
            
            if($candidate.ToLower().StartsWith($test)) {
                return $true
            }
        }
    }
    
    return $false
}

Write-Host "Hello"
$result = DotNetPackages-Get -srcFolder "/home/markr/work/personal/changelog-manager/src"
Write-Host $result 

$packageId = "CommandLineParser"
$exactMatch = $true
$update = ShouldUpdatePackage -installed $result -packageId $packageId -exactMatch $exactMatch
Write-Host "Update $packageId (exact: $exactMatch) = $update"

$packageId = "commandlineparser"
$exactMatch = $true
$update = ShouldUpdatePackage -installed $result -packageId $packageId -exactMatch $exactMatch
Write-Host "Update $packageId (exact: $exactMatch) = $update"

$packageId = "Microsoft.NET"
$exactMatch = $true
$update = ShouldUpdatePackage -installed $result -packageId $packageId -exactMatch $exactMatch
Write-Host "Update $packageId (exact: $exactMatch) = $update"

$packageId = "Microsoft.NET"
$exactMatch = $false
$update = ShouldUpdatePackage -installed $result -packageId $packageId -exactMatch $exactMatch
Write-Host "Update $packageId (exact: $exactMatch) = $update"
