#########################################################################

param(
    [string] $repos = $(throw "repos.lst file containing list of repositories"),
    [string] $work = $(throw "folder where to clone repositories"),
    [string] $packagesToUpdate = $(throw "Packages.json file to load")
)

Remove-Module *

$InformationPreference = "Continue"
$ErrorActionPreference = "Stop" 
[string]$packageIdToInstall = "Credfeto.Package.Update"
[bool]$preRelease = $False
[int]$autoReleasePendingPackages = 5

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
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "DotNetTool.psm1") -Force -DisableNameChecking
}
catch {
    Write-Error $Error[0]
    Throw "Error while loading supporting PowerShell Scripts: DotNetTool" 
}

try
{
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "GitUtils.psm1") -Force -DisableNameChecking
}
catch {
    Write-Error $Error[0]
    Throw "Error while loading supporting PowerShell Scripts: GitUtils" 
}

try
{
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "DotNetBuild.psm1") -Force -DisableNameChecking
}
catch {
    Write-Error $Error[0]
    Throw "Error while loading supporting PowerShell Scripts: DotNetBuild" 
}

try
{
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "ChangeLog.psm1") -Force -DisableNameChecking
}
catch
{
    Write-Error $Error[0]
    Throw "Error while loading supporting PowerShell Scripts: Changelog"
}

try
{
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "Tracking.psm1") -Force -DisableNameChecking
}
catch
{
    Write-Error $Error[0]
    Throw "Error while loading supporting PowerShell Scripts: Tracking"
}

try
{
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "BuildVersion.psm1") -Force -DisableNameChecking
}
catch {
    Write-Error $Error[0]
    Throw "Error while loading supporting PowerShell Scripts: BuildVersion"
}

try
{
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "Release.psm1") -Force -DisableNameChecking
}
catch
{
    Write-Error $Error[0]
    Throw "Error while loading supporting PowerShell Scripts: Release"
}
#endregion

function checkForUpdatesExact{
param(
    [String]$repoFolder, 
    [String]$packageId, 
    [Boolean]$exactMatch
    )


    Write-Information "Updating Package Exact"
    $results = dotnet updatepackages -folder $repoFolder -packageId $packageId
    if ($?)
    {

        # has updates
        [string]$packageIdAsRegex = $packageId.Replace(".", "\.").ToLower()
        [string]$regexPattern = "echo ::set-env name=$packageIdAsRegex::(?<Version>\d+(\.\d+)+)"

        $regex = new-object System.Text.RegularExpressions.Regex($regexPattern, [System.Text.RegularExpressions.RegexOptions]::MultiLine)
        $regexMatches = $regex.Matches($results.ToLower());
        if($regexMatches.Count -gt 0) {
            [string]$version = $regexMatches[0].Groups["Version"].Value
            Write-Information "Found: $version"
            return $version
        }
    }
    

    Write-Information " * No Changes"    
    return $null
}


function checkForUpdatesPrefix{
param(
    [String]$repoFolder,
    [String]$packageId
    )

    Write-Information "Updating Package Prefix"
    $results = dotnet updatepackages -folder $repoFolder -packageprefix $packageId 

    if($?) {
        
        # has updates
        [string]$packageIdAsRegex = $packageId.Replace(".", "\.").ToLower()
        [string]$regexPattern = "echo ::set-env name=$packageIdAsRegex(.*?)::(?<Version>\d+(\.\d+)+)"

        $regex = new-object System.Text.RegularExpressions.Regex($regexPattern, [System.Text.RegularExpressions.RegexOptions]::MultiLine)
        $regexMatches = $regex.Matches($results.ToLower());
        if($regexMatches.Count -gt 0) {
            [string]$version = $regexMatches[0].Groups["Version"].Value
            Write-Information "Found: $version"
            return $version
        }
    }
    
    Write-Information " * No Changes"    
    return $null
}

function checkForUpdates{
param(
    [String]$repoFolder,
    [String]$packageId,
    [Boolean]$exactMatch
)

    if ($exactMatch -eq $true)
    {
        return checkForUpdatesExact -repoFolder $repoFolder -packageId $packageId
    }
    else
    {
        return checkForUpdatesPrefix -repoFolder $repoFolder -packageId $packageId
    }
}

function BuildSolution{
param(
    [String]$srcPath,
    [String]$baseFolder,
    [String]$currentVersion
    )

    if ($lastRevision -eq $currentRevision)
    {
        Write-Information "Repo not changed since last successful build"
        Return $true
    }

    [bool]$codeOK = DotNet-BuildSolution -srcFolder $srcPath
    if ($codeOK -eq $true)
    {
        Tracking_Set -basePath $baseFolder -repo $repo -value $currentRevision
    }
}

function ShouldAlwaysCreatePatchRelease{
param(
    [string]$repo
    )
    
    if($repo.Contains("template")) {
        return $false
    }

    if($repo.Contains("credfeto")) {
        return $true
    }

    if($repo.Contains("BuildBot")) {
        return $true
    }

    if($repo.Contains("CoinBot")) {
        return $true
    }

    if($repo.Contains("funfair-server-balance-bot")) {
        return $true
    }

    return $false
}

function IsAllAutoUpdates {
param(
    [string]$releaseNotes
    )

    [int]$updateCount = 0

    [bool]$hasContent = $false
    foreach($line in $releaseNotes) {

        if($line.StartsWith("#")) {
            continue
        }

        $hasContent = $true

        #if($line.StartsWith(" - FF-1429 - ")) {
        if($line -match "^\s*\-\s*FF\-1429\s*\-\s*") {
            # Package Update
            $updateCount += 1
            continue
        }

        if($line -match "^\s*\-\s*FF\-368\s*\-\s*") {
            # GEO-IP update
            $updateCount += 1
            continue
        }

        return 0
    }

    if($hasContent) {
        return $updateCount
    }

    return 0
}


function HasPendingDependencyUpdateBranches{
param(
    [string]$repoPath
    )

    [string[]]$branches = Git-GetRemoteBranches -repoPath $repoPath -upstream "origin"
    
    foreach($branch in $branches) {
        if($branch.StartsWith("depends/")) {
            Write-Information "Found dependency update branch: $branch"
            return $true
        }

        if($branch.StartsWith("dependabot/")) {
            Write-Information "Found dependency update branch: $branch"
            return $true
        }
    }
    
    return $false
}

function removeBranchesForPrefix{
param(
    [string]$repoPath, 
    [string]$branchForUpdate, 
    [string]$branchPrefix)

    [string[]]$remoteBranches = Git-GetRemoteBranches -repoPath $repoFolder -upstream "origin"
    
    Write-Information "Looking for branches to remove based on prefix: $branchPrefix"        
    foreach($branch in $remoteBranches) {
        if($branchForUpdate) {
            if($branch -eq $branchName) {
                Write-Information "- Skipping branch just pushed to: $branch"
                continue
            }
        }
        
        if($branch.StartsWith($branchPrefix)) {
            Write-Information "+ Deleting older branch for package: $branch"
            Git-DeleteBranch -branchName $branch -repoPath $repoFolder
        }
        else {
            Write-Information "+ Skipping branch for other package: $branch"
        }
    }        
} 

function processRepo{
param(
    [string]$repo,
    $packages, 
    [string]$baseFolder
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
    if ($projects.Length -eq 0)
    {
        # no source to update
        Write-Information "* No C# projects in repo"
        return;
    }

    [string]$lastRevision = Tracking_Get -basePath $baseFolder -repo $repo
    [string]$currentRevision = Git-Get-HeadRev

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
            Tracking_Set -basePath $baseFolder -repo $repo -value $currentRevision
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

        Write-Information ""
        Write-Information "------------------------------------------------"
        Write-Information "Looking for updates of $packageId"
        Write-Information "Exact Match: $exactMatch"
        
        [string]$branchPrefix = "depends/ff-1429/update-$packageId/"
        [bool]$update = checkForUpdates -repoFolder $repoFolder -packageId $package.packageId -exactMatch $exactMatch
        
        if($update -eq $null) {
            Git-ResetToMaster
            
            removeBranchesForPrefix -repoPath $repoFolder -branchForUpdate $null -branchPrefix $branchPrefix
            
            Continue
        }

        $packagesUpdated += 1
        [string]$branchName = "$branchPrefix/$update"
        [bool]$branchExists = Git-DoesBranchExist -branchName $branchName
        if(!$branchExists) {

            Write-Information ">>>> Checking to see if code builds against $packageId $update <<<<"
            $codeOK = DotNet-BuildSolution -srcFolder $srcPath
            Set-Location -Path $repoFolder
            if($codeOK) {
                ChangeLog-AddEntry -fileName $changeLog -entryType "Changed" -code "FF-1429" -message "Updated $packageId to $update"
                Git-Commit -message "[FF-1429] Updating $packageId ($type) to $update"
                Git-Push

                # Just built, committed and pushed so get the the revisions 
                [string]$currentRevision = Git-Get-HeadRev
                [string]$lastRevision = $currentRevision
                Tracking_Set -basePath $baseFolder -repo $repo -value $currentRevision

                Write-Information "Last Revision:    $lastRevision"
                Write-Information "Current Revision: $currentRevision"
            }
            else {
                Write-Information "Create Branch $branchName"
                [bool]$branchOk = Git-CreateBranch -branchName $branchName
                if($branchOk) {
                    ChangeLog-AddEntry -fileName $changeLog -entryType "Changed" -code "FF-1429" -message "Updated $packageId to $update"
                    Git-Commit -message "[FF-1429] Updating $packageId ($type) to $update"
                    Git-PushOrigin -branchName $branchName

                    $branchesCreated += 1
                } else {
                    Write-Information ">>> ERROR: FAILED TO CREATE BRANCH <<<"
                }
            }
        }
        else {
                Write-Information "Branch $branchName already exists - skipping"
        }
 
        Git-ResetToMaster
        
        removeBranchesForPrefix -repoPath $repoFolder -branchForUpdate $branchName -branchPrefix $branchPrefix
    }
    
    Write-Information "Updated run created $branchesCreated branches"
    Write-Information "Updated run updated $packagesUpdated packages"
    
    Git-ResetToMaster
    
    if($branchesCreated -eq 0) {
        # no branches created - check to see if we can create a release
        
        if(!$repo.Contains("template")) {
            [string]$releaseNotes = ChangeLog-GetUnreleased -fileName $changeLog
            [int]$autoUpdateCount = IsAllAutoUpdates -releaseNotes $releaseNotes
            
            if( $autoUpdateCount -ge $autoReleasePendingPackages) {
                # At least $autoReleasePendingPackages auto updates... consider creating a release
                
                [bool]$hasPendingDependencyUpdateBranches = HasPendingDependencyUpdateBranches -repoPath $repoPath
                if(!$hasPendingDependencyUpdateBranches) {            
                    if (ShouldAlwaysCreatePatchRelease -repo $repo) {
                        Write-Information "**** MAKE RELEASE ****"
                        Write-Information "Changelog: $changeLog"
                        Write-Information "Repo: $repoFolder"
                        Release-Create -repo $repo -changelog $changeLog -repoPath $repoFolder
                    }
                    else {
                        if(!$repo.Contains("server-content-package"))
                        {
                            [bool]$publishable = DotNet-HasPublishableExe -srcFolder $srcPath
                            if (!$publishable -and !$repo.Contains("template"))
                            {
                                Write-Information "**** MAKE RELEASE ****"
                                Write-Information "Changelog: $changeLog"
                                Write-Information "Repo: $repoFolder"
                                Release-Create -repo $repo -changelog $changeLog -repoPath $repoFolder
                            }
                        }
                    }
                }
            }
        }
    }
}

#########################################################################


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



Write-Information ""
Write-Information "***************************************************************"
Write-Information "***************************************************************"
Write-Information ""

$packages = Get-Content -Path $packagesToUpdate -Raw | ConvertFrom-Json

[string[]] $repoList = Git-LoadRepoList -repoFile $repos
ForEach($repo in $repoList) {
    if($repo.Trim() -eq "") {
        continue
    }

    processRepo -repo $repo -packages $packages -baseFolder $root
}

Set-Location -Path $root

Write-Information ">>>>>>>>>>>> ALL REPOS PROCESSED <<<<<<<<<<<<"

