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

[bool]$installed = DotNetTool-Install -packageId "Credfeto.Changelog.Cmd" -preReleaseVersion $preRelease
Write-Host $installed

if($installed -eq $false) {
    Write-Error ""
    Write-Error "#teamcity[buildStatus status='FAILURE' text='Failed to install Credfeto.Changelog.Cmd']"
}

$changelog = "/data/work/funfair/funfair-server-code-analysis/CHANGELOG.md"

$file = Get-Content -Path $changelog

# Write-Host $file

$expr = "(?ms)" + "^\s*\-\s*FF\-1429\s*\-\sUpdated\s+(?<PackageId>.+(\.+)*?)\sto\s+(\d+\..*)$"
foreach($line in $file) {

    $m = $line -match $expr
    if($m) {    
        Write-Host $matches.PackageId
    }
}

$unixTime = git log -1 --format=%ct

[DateTime]$when = [DateTimeOffset]::FromUnixTimeSeconds($unixTime).UtcDateTime
[DateTime]$now = $now = [DateTime]::UtcNow

[TimeSpan]$difference = $now - $when
[double]$duration = $difference.TotalHours 

Write-Host $when
Write-Host $now

Write-Host $duration
