#########################################################################

param(
    [string] $packageId = $(throw "the packageId to install"),
)

Remove-Module *
Set-StrictMode -Version 1

$InformationPreference = "Continue"
$ErrorActionPreference = "Stop"
[bool]$preRelease = $False

# Ensure $root is set to a valid path
$workDir = Resolve-Path -path $work
[string]$root = $workDir.Path
if($root.Contains("/../")){
    Write-Error "Work folder: $work"
    Write-Error "Base folder: $root"
    throw "Invalid Base Folder: $root"
}

Write-Information $root
Write-Information "Base folder: $root"
Set-Location -Path $root


#########################################################################
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

DotNetTool-Install -packageId $packageId -preReleaseVersion $preRelease

