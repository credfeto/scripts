#########################################################################

param(
    [string] $work = $(throw "folder where to clone repositories"),
    [string] $packageCacheToRead = $(throw "package cache file to read"),
    [string] $packageCacheToWrite = $(throw "package cache file to write"),
    [string] $packagesToUpdate = $(throw "Packages.json file to load")
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

$ScriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
$ScriptDirectory = Join-Path -Path $ScriptDirectory -ChildPath "lib" 
Write-Information "Loading Modules from $ScriptDirectory"
try {
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "CheckForPackages.psm1") -Force -DisableNameChecking
}
catch {
    Write-Error "$_"
    Throw "Error while loading supporting PowerShell Scripts: CheckForPackages" 
}

try {
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "DotNetTool.psm1") -Force -DisableNameChecking
}
catch {
    Write-Error "$_"
    Throw "Error while loading supporting PowerShell Scripts: DotNetTool" 
}

try
{
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "GitUtils.psm1") -Force -DisableNameChecking
}
catch {
    Write-Error "$_"
    Throw "Error while loading supporting PowerShell Scripts: GitUtils" 
}

try
{
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "DotNetBuild.psm1") -Force -DisableNameChecking
}
catch {
    Write-Error "$_"
    Throw "Error while loading supporting PowerShell Scripts: DotNetBuild" 
}

try
{
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "ChangeLog.psm1") -Force -DisableNameChecking
}
catch
{
    Write-Error "$_"
    Throw "Error while loading supporting PowerShell Scripts: Changelog"
}

try
{
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "Tracking.psm1") -Force -DisableNameChecking
}
catch
{
    Write-Error "$_"
    Throw "Error while loading supporting PowerShell Scripts: Tracking"
}

try
{
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "BuildVersion.psm1") -Force -DisableNameChecking
}
catch {
    Write-Error "$_"
    Throw "Error while loading supporting PowerShell Scripts: BuildVersion"
}

try
{
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "Release.psm1") -Force -DisableNameChecking
}
catch
{
    Write-Error "$_"
    Throw "Error while loading supporting PowerShell Scripts: Release"
}

try {
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "DotNetPackages.psm1") -Force -DisableNameChecking
}
catch {
    Write-Error "$_"
    Throw "Error while loading supporting PowerShell Scripts: DotNetPackages"
}
#endregion

function BuildSolution{
param(
    [String]$srcPath = $(throw "BuildSolution: srcPath not specified"),
    [String]$baseFolder = $(throw "BuildSolution: baseFolder not specified"),
    [String]$currentVersion = $(throw "BuildSolution: currentVersion not specified")
    )

    if ($lastRevision -eq $currentRevision)
    {
        Write-Information "Repo not changed since last successful build"
        Return $true
    }

    [bool]$codeOK = DotNet-BuildSolution -srcFolder $srcPath
    if ($codeOK -eq $true)
    {
        Tracking_Set -basePath $trackingFolder -repo $repo -value $currentRevision
    }
}

function ProcessFolder{
param(
    [string]$folder = $(throw "ProcessFolder: repo not specified"),
    $packages = $(throw "ProcessFolder: packages not specified"),
    [string]$packageCache= $(throw "ProcessFolder: packageCache not specified")
    )


    Set-Location -Path $folder

    Write-Information ""
    Write-Information "***********************************************************************************"
    Write-Information "***********************************************************************************"
    Write-Information "***********************************************************************************"
    Write-Information "***********************************************************************************"
    Write-Information ""
    Write-Information "Processing Cache folder: $folder"

    $currentlyInstalledPackages = DotNetPackages-Get -srcFolder $folder
    if($currentlyInstalledPackages.Length -eq 0) {
        # no source to update
        Write-Information "* No C# packages to update"
        return;
    }    

    [int]$packagesUpdated = 0
    ForEach ($package in $packages)
    {
        [string]$packageId = $package.packageId.Trim('.')
        [string]$type = $package.type
        [bool]$exactMatch = $package.'exact-match'
        
        [bool]$shouldUpdatePackages = Packages_ShouldUpdate -installed $currentlyInstalledPackages -packageId $packageId -exactMatch $exactMatch
        
        Write-Information ""
        Write-Information "------------------------------------------------"
        Write-Information "Looking for updates of $packageId"
        Write-Information "Exact Match: $exactMatch"
        Write-Information "Package installed in solution: $shouldUpdatePackages"
                
        if(!$shouldUpdatePackages) {
            Write-Information "Skipping $packageId as not installed"
            continue
        }
        
        [string]$update = Packages_CheckForUpdates -repoFolder $folder -packageCache $packageCache -packageId $package.packageId -exactMatch $exactMatch -exclude $package.exclude
        
        if([string]::IsNullOrEmpty($update)) {
            Write-Information "***** $repo NO UPDATES TO $packageId ******"
            
            # Git-RemoveBranchesForPrefix -repoPath $repoFolder -branchForUpdate $null -branchPrefix $branchPrefix
            
            Continue
        }

        Write-Information "***** $repo FOUND UPDATE TO $packageId for $update ******"
        
        $packagesUpdated += 1
    }
    
    Write-Information "Cache update run updated $packagesUpdated packages"
}

function CreateProject {
param(
 $packageCache = $(throw "CreateProject: packageCache not specified"),
 $workFolder = $(throw "CreateProject: workFolder not specified")
)

    $packageCacheContent = Get-Content -Path $packageCache -Raw | ConvertFrom-Json
    
    $project = Join-Path -Path $workFolder -ChildPath "Package.Cache.Update.Temp.csproj"
    Write-Information "Creating project $project..."
    
    $projectContent = "<Project Sdk=`"Microsoft.NET.Sdk`">" + "`r`n"
    $projectContent += "  <ItemGroup>" + "`r`n"
    foreach($package in $packageCacheContent.PSObject.Properties) {
        $packageId = $package.Name
        $version = $package.Value
        Write-Information "* Package: $packageId - $version"
        $projectContent += "    <PackageReference Include=`"$packageId`" Version=`"$version`" />"
    }
    $projectContent += "  </ItemGroup>" + "`r`n"
    $projectContent += "</Project>" + "`r`n"
    Set-Content -Path $project -Value $projectContent
    Write-Information "Done $project..."
}

#########################################################################

Write-Information ""
Write-Information "***************************************************************"
Write-Information "***************************************************************"
Write-Information ""

Set-Location -Path $root
Write-Information "Root Folder: $root"

DotNetTool-Require -packageId "Credfeto.Package.Update"
DotNetTool-Require -packageId "Credfeto.Changelog.Cmd"
DotNetTool-Require -packageId "FunFair.BuildVersion"
DotNetTool-Require -packageId "FunFair.BuildCheck"

Write-Information ""
Write-Information "***************************************************************"
Write-Information "***************************************************************"
Write-Information ""

$packages = Packages_Get -fileName $packagesToUpdate


$packageWorkFolder = Join-Path -Path $root -ChildPath "Package.Cache.Update.Temp"
$packageWorkFolderExists = Test-Path -Path $packageWorkFolder
if(!$packageWorkFolderExists) {
    New-Item -ItemType Directory -Path $packageWorkFolder
}

CreateProject -packageCache $packageCacheToRead -workFolder $packageWorkFolder

$packageCacheToWriteExists = Test-Path -Path $packageCacheToWrite
if($packageCacheToWriteExists) {
    Remove-Item -Path $packageCacheToWrite -Recurse -Force
}

ProcessFolder -folder $packageWorkFolder -packages $packages -packageCache $packageCacheToWrite
###############

Write-Information ">>>>>>>>>>>> COMPLETE <<<<<<<<<<<<"

