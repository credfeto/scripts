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
    Write-Error "$_"
    Throw "Error while loading supporting PowerShell Scripts: DotNetTool"
}

try {
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "GitUtils.psm1") -Force -DisableNameChecking
}
catch {
    Write-Error "$_"
    Throw "Error while loading supporting PowerShell Scripts: GitUtils"
}

try {
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "DotNetPackages.psm1") -Force -DisableNameChecking
}
catch {
    Write-Error "$_"
    Throw "Error while loading supporting PowerShell Scripts: DotNetPackages"
}

try {
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "Labeler.psm1") -Force -DisableNameChecking
}
catch {
    Write-Error "$_"
    Throw "Error while loading supporting PowerShell Scripts: Labeler"
}

try
{
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "GlobalJson.psm1") -Force -DisableNameChecking
}
catch
{
    Write-Error "$_"
    Throw "Error while loading supporting PowerShell Scripts: GlobalJson"
}

try {
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "XmlDoc.psm1") -Force -DisableNameChecking
}
catch {
    Write-Error "$_"
    Throw "Error while loading supporting PowerShell Scripts: XmlDoc"
}

#$ret = GlobalJson_Update -sourceFileName '/home/markr/work/funfair/funfair-build-check/src/global.json' -targetFileName '/home/markr/work/funfair/BuildBot/src/global.json'
#Write-Host $ret

DotNetTool-Install -packageId 'FunFair.BuildCheck' -preReleaseVersion $false



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

#function ShouldUpdatePackage{
#param (
#    $installed,
#    [string]$packageId,
#    [bool]$exactMatch
#)
#
#    foreach($candidate in $installed) {
#        if($packageId -eq $candidate) {
#            return $true
#        }
#
#        if(!$exactMatch) {
#            $test = "$packageId.".ToLower()
#            
#            if($candidate.ToLower().StartsWith($test)) {
#                return $true
#            }
#        }
#    }
#    
#    return $false
#}
#
#Write-Host "Hello"
#$result = DotNetPackages-Get -srcFolder "/home/markr/work/personal/changelog-manager/src"
#Write-Host $result 
#
#$packageId = "CommandLineParser"
#$exactMatch = $true
#$update = ShouldUpdatePackage -installed $result -packageId $packageId -exactMatch $exactMatch
#Write-Host "Update $packageId (exact: $exactMatch) = $update"
#
#$packageId = "commandlineparser"
#$exactMatch = $true
#$update = ShouldUpdatePackage -installed $result -packageId $packageId -exactMatch $exactMatch
#Write-Host "Update $packageId (exact: $exactMatch) = $update"
#
#$packageId = "Microsoft.NET"
#$exactMatch = $true
#$update = ShouldUpdatePackage -installed $result -packageId $packageId -exactMatch $exactMatch
#Write-Host "Update $packageId (exact: $exactMatch) = $update"
#
#$packageId = "Microsoft.NET"
#$exactMatch = $false
#$update = ShouldUpdatePackage -installed $result -packageId $packageId -exactMatch $exactMatch
#Write-Host "Update $packageId (exact: $exactMatch) = $update"
#
#
#Labels_Update -prefix "Credfeto.Notification.Bot" -sourceFilesBase "/home/markr/work/personal/notification-bot/src" -labelerFileName "/home/markr/work/personal/notification-bot/.github/labeler.yml" -labelsFileName "/home/markr/work/personal/notification-bot/.github/labels.yml"


# $branch = Git-GetDefaultBranch -repoPath '~/work/funfair/funfair-ethereum-proxy-server'
# Write-Host "Default Branch: $branch"
# 
# XmlDoc_RemoveComments -sourceFolder "~/work/personal/notification-bot/src"
# XmlDoc_DisableDocComment -sourceFolder "~/work/personal/notification-bot/src"

# function buildPackageSearch{
#     param(
#         [string]$packageId,
#         [bool]$exactMatch
#     )
#     
#     if($exactMatch) {
#         return $packageId
#     }
#     
#     return "$($packageId):prefix"
# }
# 
# function buildExcludes{
# param(
#     $exclude
#     )
#     
#     $excludes =@()
#     foreach($item in $exclude)
#     {
#         [string]$packageId = $item.packageId
#         [boolean]$exactMatch = $item.'exact-match'
#         $search = buildPackageSearch -packageId $packageId -exactMatch $exactMatch         
#         $excludes += $search
#                 
#     }
#     
#     if($excludes.Count -gt 0) {
#         $excluded = $excludes -join " "
#         Write-Information "Excluding: $excluded"        
#         return $excludes
#     }
#     else {
#         Write-Information "Excluding: <<None>>"
#         return $null        
#     }
# }
# 
# 
# $packages = Get-Content -Path "~/work/personal/auto-update-config/packages.json" -Raw | ConvertFrom-Json
# Write-Host $packages 
# 
# foreach($package in $packages) {
#     
#     if($package.packageId -eq "FunFair.Ethereum") {
#         Write-Host "* $($package.packageId)"
#         Write-Host "  --> Found"
#         
#         foreach($exclusion in $package.exclude) {
#             Write-Host "  --> Exclusion: $($exclusion.packageId)"
#         }
#         
#         $excluded = buildExcludes -exclude $package.exclude
#         Write-Host "  *--> Exclusion: $excluded"
#         
#         $search = buildPackageSearch -packageId $package.packageId -exactMatch $package.'exact-match'
#         dotnet updatepackages --package-id $search --folder /home/markr/work/funfair/funfair-ethereum-gas-server/src --source https://funfair.myget.org/F/internal/auth/071ea13d-90dd-4b3d-a2be-6133beba5d05/api/v3/index.json --exclude $excluded
#     }
# }