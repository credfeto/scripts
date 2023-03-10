#########################################################################

param(
    [string] $repos = $(throw "repos.lst file containing list of repositories"),
    [string] $work = $(throw "folder where to clone repositories"),
    [string] $trackingFolder = $(throw "folder where to write tracking.json file"),
    [string] $packageCache = $(throw "package cache file"),
    [string] $packagesToUpdate = $(throw "Packages.json file to load")
)

Remove-Module *
Set-StrictMode -Version 1

$InformationPreference = "Continue"
$ErrorActionPreference = "Stop" 
[string]$packageIdToInstall = "Credfeto.Package.Update"
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


function processRepo{
param(
    [string]$repo = $(throw "processRepo: repo not specified"),
    $packages = $(throw "processRepo: packages not specified"), 
    [string]$baseFolder = $(throw "processRepo: baseFolder not specified")
    )


    Set-Location -Path $root

    Write-Information ""
    Write-Information "***********************************************************************************"
    Write-Information "***********************************************************************************"
    Write-Information "***********************************************************************************"
    Write-Information "***********************************************************************************"
    Write-Information ""
    Write-Information "Processing Repo: $repo"

    # Extract the folder from the repo name
    [string]$folder = Git-GetFolderForRepo -repo $repo

    Write-Information "Folder: $folder"
    [string]$repoFolder = Join-Path -Path $root -ChildPath $folder

    Git-EnsureSynchronised -repo $repo -repofolder $repoFolder

    [string]$srcPath = Join-Path -Path $repoFolder -ChildPath "src"
    [bool]$srcExists = Test-Path -Path $srcPath
    if($srcExists -eq $false) {
        # no source to update
        Write-Information "* No src folder in repo"
        return;
    }

    $projects = Get-ChildItem -Path $srcPath -Filter *.csproj -Recurse
    if ($projects.Length -eq 0) {
        # no source to update
        Write-Information "* No C# projects in repo"
        return;
    }
    
    $currentlyInstalledPackages = DotNetPackages-Get -srcFolder $srcPath
    if($currentlyInstalledPackages.Length -eq 0) {
        # no source to update
        Write-Information "* No C# packages to update in repo"
        return;
    }    

    [string]$lastRevision = Tracking_Get -basePath $trackingFolder -repo $repo
    [string]$currentRevision = Git-Get-HeadRev -repoPath $repoFolder

    Write-Information "Last Revision:    $lastRevision"
    Write-Information "Current Revision: $currentRevision"

    [string]$changeLog = Join-Path -Path $repoFolder -ChildPath "CHANGELOG.md"

    [bool]$codeOK = $false
    if ($lastRevision -eq $currentRevision)
    {
        # no need to build - it last built successfully with this code revision
        $codeOK = $true
    }
    else
    {
        $codeOK = DotNet-BuildSolution -srcFolder $srcPath
        if ($codeOk -eq $true)
        {
            # Update last successful revision
            [string]$lastRevision = $currentRevision
            Tracking_Set -basePath $trackingFolder -repo $repo -value $currentRevision
        }
    }

    Set-Location -Path $repoFolder
    if ($codeOk -eq $false)
    {
        # no point updating
        Write-Information "* WARNING: Solution doesn't build without any changes - no point in trying to update packages"
        return;
    }
    
    [int]$branchesCreated = 0
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
        
        [boolean]$okBefore = DotNet-CheckSolution -srcFolder $srcPath
        if(!$okBefore) {
            Write-Information "Skipping $packageId as solution is not in a good state"
            continue
        }
        
        [string]$branchPrefix = "depends/update-$packageId/"
        [string]$update = Packages_CheckForUpdates -repoFolder $repoFolder -packageCache $packageCache -packageId $package.packageId -exactMatch $exactMatch -exclude $package.exclude
        
        if([string]::IsNullOrEmpty($update)) {
            Write-Information "***** $repo NO UPDATES TO $packageId ******"
            Git-ResetToMaster -repoPath $repoFolder
            
            # Git-RemoveBranchesForPrefix -repoPath $repoFolder -branchForUpdate $null -branchPrefix $branchPrefix
            
            Continue
        }

        Write-Information "***** $repo FOUND UPDATE TO $packageId for $update ******"
        
        [boolean]$okAfter = DotNet-CheckSolution -srcFolder $srcPath
        if(!$okAfter) {
            Write-Information "Skipping $packageId as solution is not in a good state after update attempt (probable mismatch of packages)"
            continue
        }
                
        $packagesUpdated += 1
        [string]$branchName = "$branchPrefix$update"
        [bool]$branchExists = Git-DoesBranchExist -branchName $branchName  -repoPath $repoFolder
        if(!$branchExists) {

            Write-Information ">>>> Checking to see if code builds against $packageId $update <<<<"
            $codeOK = DotNet-BuildSolution -srcFolder $srcPath
            Set-Location -Path $repoFolder
            if($codeOK) {
                ChangeLog-RemoveEntry -fileName $changeLog -entryType "Changed" -code "Dependencies" -message "Updated $packageId to "
                ChangeLog-AddEntry -fileName $changeLog -entryType "Changed" -code "Dependencies" -message "Updated $packageId to $update"
                Git-Commit -message "[Dependencies] Updating $packageId ($type) to $update"  -repoPath $repoFolder
                Git-Push -repoPath $repoFolder

                # Just built, committed and pushed so get the the revisions 
                [string]$currentRevision = Git-Get-HeadRev -repoPath $repoFolder
                [string]$lastRevision = $currentRevision
                Tracking_Set -basePath $trackingFolder -repo $repo -value $currentRevision

                Write-Information "Last Revision:    $lastRevision"
                Write-Information "Current Revision: $currentRevision"

                Write-Information "WARNING: Removing other branches similar to $branchPrefix as committed to master for $update"
                Git-RemoveBranchesForPrefix -repoPath $repoFolder -branchForUpdate $branchName -branchPrefix $branchPrefix
            }
            else {
                Write-Information "Create Branch $branchName"
                [bool]$branchOk = Git-CreateBranch -branchName $branchName -repoPath $repoFolder
                if($branchOk) {
                    ChangeLog-RemoveEntry -fileName $changeLog -entryType "Changed" -code "Dependencies" -message "Updated $packageId to "
                    ChangeLog-AddEntry -fileName $changeLog -entryType "Changed" -code "Dependencies" -message "Updated $packageId to $update"
                    Git-Commit -message "[Dependencies] Updating $packageId ($type) to $update"  -repoPath $repoFolder
                    Git-PushOrigin -branchName $branchName  -repoPath $repoFolder

                    $branchesCreated += 1

                    Write-Information "WARNING: Removing other branches similar to $branchPrefix as new branch created for $update ($branchName)"
                    Git-RemoveBranchesForPrefix -repoPath $repoFolder -branchForUpdate $branchName -branchPrefix $branchPrefix
                } else {
                    Write-Information ">>> ERROR: FAILED TO CREATE BRANCH <<<"
                }
            }
        }
        else {
            Write-Information "Branch $branchName already exists - skipping"
        }
 
        Git-ResetToMaster -repoPath $repoFolder
    }
    
    Write-Information "Updated run created $branchesCreated branches"
    Write-Information "Updated run updated $packagesUpdated packages"
    
    Git-ResetToMaster -repoPath $repoFolder
        
    if($branchesCreated -eq 0) {
        # no branches created - check to see if we can create a release
        if($packagesUpdated -eq 0) {
            Release-TryCreateNextPatch -repo $repo -repoPath $repoFolder -changeLog $changeLog
        }
        else {
            Write-Information "SKIPPING RELEASE: Updated $packagesUpdated during this run"
        }
    }
    else {
        Write-Information "SKIPPING RELEASE: Created $branchesCreated during this run"
    }
}

#########################################################################

Write-Information ""
Write-Information "***************************************************************"
Write-Information "***************************************************************"
Write-Information ""

Set-Location -Path $root
Write-Information "Root Folder: $root"

[bool]$installed = DotNetTool-Install -packageId $packageIdToInstall -preReleaseVersion $preRelease

if($installed -eq $false) {
    Write-Error ""
	Write-Error "#teamcity[buildStatus status='FAILURE' text='Failed to install $packageIdToInstall']"
}

[bool]$installed = DotNetTool-Install -packageId "Credfeto.Changelog.Cmd" -preReleaseVersion $preRelease

if($installed -eq $false) {
    Write-Error ""
	Write-Error "#teamcity[buildStatus status='FAILURE' text='Failed to install FunFair.BuildVersion']"
}

[bool]$installed = DotNetTool-Install -packageId "FunFair.BuildVersion" -preReleaseVersion $preRelease

if($installed -eq $false) {
    Write-Error ""
    Write-Error "#teamcity[buildStatus status='FAILURE' text='Failed to install FunFair.BuildVersion']"
}

[bool]$installed = DotNetTool-Install -packageId "FunFair.BuildCheck" -preReleaseVersion $preRelease

if($installed -eq $false) {
    Write-Error ""
    Write-Error "#teamcity[buildStatus status='FAILURE' text='Failed to install FunFair.BuildCheck']"
}

Write-Information ""
Write-Information "***************************************************************"
Write-Information "***************************************************************"
Write-Information ""

$packages = Packages_Get -fileName $packagesToUpdate

[string[]] $repoList = Git-LoadRepoList -repoFile $repos
ForEach($repo in $repoList) {
    if($repo.Trim() -eq "") {
        continue
    }

    processRepo -repo $repo -packages $packages -baseFolder $root
}

Write-Information ">>>>>>>>>>>> ALL REPOS PROCESSED <<<<<<<<<<<<"

