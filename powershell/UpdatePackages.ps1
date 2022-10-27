#########################################################################

param(
    [string] $repos = $(throw "repos.lst file containing list of repositories"),
    [string] $work = $(throw "folder where to clone repositories"),
    [string] $packagesToUpdate = $(throw "Packages.json file to load")
)

Remove-Module *
Set-StrictMode -Version 1

$InformationPreference = "Continue"
$ErrorActionPreference = "Stop" 
[string]$packageIdToInstall = "Credfeto.Package.Update"
[bool]$preRelease = $False
[int]$autoReleasePendingPackages = 3
[double]$minimumHoursBeforeAutoRelease = 4
[double]$inactivityHoursBeforeAutoRelease = 2 * $minimumHoursBeforeAutoRelease
 
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

function buildPackageSearch{
    param(
        [string]$packageId,
        [bool]$exactMatch
    )
    
    if($exactMatch) {
        return $packageId
    }
    
    return "$($packageId):prefix"
}

function buildExcludes{
param(
    $exclude
    )
    
    $excludes =@()
    foreach($item in $exclude)
    {
        [string]$packageId = $item.packageId
        [boolean]$exactMatch = $item.'exact-match'
        $search = buildPackageSearch -packageId $packageId -exactMatch $exactMatch         
        $excludes += $search
    }
    
    if($excludes.Count -gt 0) {
        $excluded = $excludes -join " "
        Write-Information "Excluding: $excluded"
        return $excluded
    }
    else {
        Write-Information "Excluding: <<None>>"
        return $null        
    }
}


function checkForUpdatesExact{
param(
    [String]$repoFolder = $(throw "checkForUpdatesExact: repoFolder not specified"), 
    [String]$packageId = $(throw "checkForUpdatesExact: packageId not specified"),
    $exclude    
    )

    $restore = dotnet tool restore
    if (!$?) {
       throw $restore
    }

    Write-Information "Updating Package Exact"
    $search = buildPackageSearch -packageId $packageId -exactMatch $True
    $excludes = buildExcludes -exclude $exclude
    if($excludes) {
        $results = dotnet updatepackages --folder $repoFolder --package-id $search --exclude $excludes
    }
    else {
        $results = dotnet updatepackages --folder $repoFolder --package-id $search
    }    
    if ($?)
    {
        Write-Information $results
        
        # has updates
        [string]$packageIdAsRegex = $packageId.Replace(".", "\.").ToLower()
        [string]$regexPattern = "::set-env name=$packageIdAsRegex::(?<Version>\d+(\.\d+)+)"

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
    [String]$repoFolder = $(throw "checkForUpdatesPrefix: repoFolder not specified"),
    [String]$packageId = $(throw "checkForUpdatesPrefix: packageId not specified"),
    $exclude
    )

    $restore = dotnet tool restore
    if (!$?) {
       throw $restore
    }

    Write-Information "Updating Package Prefix"
    $search = buildPackageSearch -packageId $packageId -exactMatch $False
    $excludes = buildExcludes -exclude $exclude
    if($excludes) {
        $results = dotnet updatepackages --folder $repoFolder --package-id $search --exclude $excludes
    }
    else {
        $results = dotnet updatepackages --folder $repoFolder --package-id $search
    }

    if($?) {
        
        Write-Information $results
        
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
    [String]$repoFolder = $(throw "checkForUpdates: repoFolder not specified"),
    [String]$packageId = $(throw "checkForUpdates: packageId not specified"),
    [Boolean]$exactMatch,
    $exclude
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
        Tracking_Set -basePath $baseFolder -repo $repo -value $currentRevision
    }
}

function ShouldAlwaysCreatePatchRelease{
param(
    [string]$repo = $(throw "ShouldAlwaysCreatePatchRelease: repo not specified")
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

function IsPackageConsideredForVersionUpdate {
param (
    $packages = $(throw "IsPackageConsideredForVersionUpdate: packages not specified"),
    [string] $packageName = $(throw "IsPackageConsideredForVersionUpdate: packageName not specified")
    )
    
    ForEach ($package in $packages)
    {
        [string]$packageId = $package.packageId.Trim('.')
        if($packageName -eq $packageId) {
            [bool]$ignore = $package.'prohibit-version-bump-when-referenced'
            if($ignore) {
                Write-Information "IGNORING $packageId for update"
                return false
            }
        }
    }

    return $true    
}

function IsAllAutoUpdates {
param(
    [string[]]$releaseNotes = $(throw "IsAllAutoUpdates: releaseNotes not specified"),
    $packages = $(throw "IsAllAutoUpdates: packages not specified")
    )

    [string]$expr = "(?ms)" + "^\s*\-\s*FF\-1429\s*\-\sUpdated\s+(?<PackageId>.+(\.+)*?)\sto\s+(\d+\..*)$"
    
    [int]$updateCount = 0

    [bool]$hasContent = $false
    foreach($line in $releaseNotes) {

        if($line.StartsWith("#")) {
            continue
        }
        
        if([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        $hasContent = $true
        
        if($line -match $expr) {            
            # Package Update
            $packageName = $matches.PackageId
            if(IsPackageConsideredForVersionUpdate -packages $packages -packageName $packageName) {
                Write-Information "Found Matching Update: $packageName"
                $updateCount += 1
            } else {
                Write-Information "Skipping Ignored Update: $packageName"
            }
            continue
        }

        if($line -match "^\s*\-\s*FF\-368\s*\-\s*") {
            # GEO-IP update
            $updateCount += 1
            continue
        }
        
        if($line.StartsWith("- FF-3881 - Updated DotNet SDK to ")) {
            # Dotnet version update
            $updateCount += 1000
            continue
        }
    }

    if($hasContent) {
        return $updateCount
    }

    return 0
}


function HasPendingDependencyUpdateBranches{
param(
    [string]$repoPath = $(throw "HasPendingDependencyUpdateBranches: repoPath not specified")
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

function CheckRepoForAllowedAutoUpgrade {
param (
    [string]$repo = $(throw "CheckRepoForAllowedAutoUpgrade: repo not specified")
    )
    
    if($repo.Contains("server-content-package")) {
        return $false
    }
    
    if($repo.Contains("code-analysis")) {
        return $false
    }

    return $true
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

    [string]$lastRevision = Tracking_Get -basePath $baseFolder -repo $repo
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
        [string]$update = checkForUpdates -repoFolder $repoFolder -packageId $package.packageId -exactMatch $exactMatch -exclude $package.exclude
        
        if([string]::IsNullOrEmpty($update)) {
            Write-Information "***** $repo NO UPDATES TO $packageId ******"
            Git-ResetToMaster -repoPath $repoFolder
            
            # Git-RemoveBranchesForPrefix -repoPath $repoFolder -branchForUpdate $null -branchPrefix $branchPrefix
            
            Continue
        }

        Write-Information "***** $repo FOUND UPDATE TO $packageId for $update ******"
        
        $packagesUpdated += 1
        [string]$branchName = "$branchPrefix$update"
        [bool]$branchExists = Git-DoesBranchExist -branchName $branchName  -repoPath $repoFolder
        if(!$branchExists) {

            Write-Information ">>>> Checking to see if code builds against $packageId $update <<<<"
            $codeOK = DotNet-BuildSolution -srcFolder $srcPath
            Set-Location -Path $repoFolder
            if($codeOK) {
                ChangeLog-RemoveEntry -fileName $changeLog -entryType "Changed" -code "FF-1429" -message "Updated $packageId to "
                ChangeLog-AddEntry -fileName $changeLog -entryType "Changed" -code "FF-1429" -message "Updated $packageId to $update"
                Git-Commit -message "[FF-1429] Updating $packageId ($type) to $update"  -repoPath $repoFolder
                Git-Push -repoPath $repoFolder

                # Just built, committed and pushed so get the the revisions 
                [string]$currentRevision = Git-Get-HeadRev -repoPath $repoFolder
                [string]$lastRevision = $currentRevision
                Tracking_Set -basePath $baseFolder -repo $repo -value $currentRevision

                Write-Information "Last Revision:    $lastRevision"
                Write-Information "Current Revision: $currentRevision"

                Write-Information "WARNING: Removing other branches similar to $branchPrefix as committed to master for $update"
                Git-RemoveBranchesForPrefix -repoPath $repoFolder -branchForUpdate $branchName -branchPrefix $branchPrefix
            }
            else {
                Write-Information "Create Branch $branchName"
                [bool]$branchOk = Git-CreateBranch -branchName $branchName -repoPath $repoFolder
                if($branchOk) {
                    ChangeLog-RemoveEntry -fileName $changeLog -entryType "Changed" -code "FF-1429" -message "Updated $packageId to "
                    ChangeLog-AddEntry -fileName $changeLog -entryType "Changed" -code "FF-1429" -message "Updated $packageId to $update"
                    Git-Commit -message "[FF-1429] Updating $packageId ($type) to $update"  -repoPath $repoFolder
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
            Write-Information "Checking if can create release for $repo"
            
            if(!$repo.Contains("template")) {
                Write-Information "Processing Release Notes in $changeLog"
                
                [string[]]$releaseNotes = ChangeLog-GetUnreleased -fileName $changeLog
                foreach($line in $releaseNotes) {
                    Write-Information $line
                }
                [int]$autoUpdateCount = IsAllAutoUpdates -releaseNotes $releaseNotes -packages $packages
                
                Write-Information "Checking Versions: Updated: $autoUpdateCount Trigger: $autoReleasePendingPackages"
                [DateTime]$lastCommitDate = Get-GetLastCommitDate -repoPath $repoFolder
                [DateTime]$now = [DateTime]::UtcNow                                    
                
                [TimeSpan]$durationTimeSpan = ($now - $lastCommitDate)
                $duration = $durationTimeSpan.TotalHours
                Write-Information "Duration since last commit $duration hours"

                [string]$skippingReason = "INSUFFICIENT UPDATES"                
                [bool]$shouldCreateRelease = $false
                if($autoUpdateCount -ge $autoReleasePendingPackages) {
                    if($duration -gt $minimumHoursBeforeAutoRelease) {
                        $shouldCreateRelease = $true
                        [string]$skippingReason = "RELEASING NORMAL"
                    }
                    else {
                        [string]$skippingReason = "INSUFFICIENT DURATION SINCE LAST UPDATE"
                    }
                }
                
                if(!$shouldCreateRelease) {
                    if($autoUpdateCount -ge 1) {
                        if($duration -gt $inactivityHoursBeforeAutoRelease) {
                            $shouldCreateRelease = $true
                            [string]$skippingReason = "RELEASING AFTER INACTIVITY"
                        }
                    }
                }

                if($shouldCreateRelease ) {
                    # At least $autoReleasePendingPackages auto updates... consider creating a release
                    
                    [bool]$hasPendingDependencyUpdateBranches = HasPendingDependencyUpdateBranches -repoPath $repoFolder
                    if(!$hasPendingDependencyUpdateBranches) {            
                        if (ShouldAlwaysCreatePatchRelease -repo $repo) {
                            Write-Information "**** MAKE RELEASE ****"
                            Write-Information "Changelog: $changeLog"
                            Write-Information "Repo: $repoFolder"
                            Write-Information "Reason: $skippingReason"
                            Release-Create -repo $repo -changelog $changeLog -repoPath $repoFolder
                        }
                        else {
                            $allowUpdates = CheckRepoForAllowedAutoUpgrade -repo $repo
                            if($allowUpdates) {
                                [bool]$publishable = DotNet-HasPublishableExe -srcFolder $srcPath
                                if (!$publishable) {
                                    Write-Information "**** MAKE RELEASE ****"
                                    Write-Information "Changelog: $changeLog"
                                    Write-Information "Repo: $repoFolder"
                                    Write-Information "Reason: $skippingReason"
                                    Release-Create -repo $repo -changelog $changeLog -repoPath $repoFolder
                                }
                                else {
                                    Write-Information "SKIPPING RELEASE: $repo contains publishable executables"
                                }
                            }
                            else {
                                Write-Information "SKIPPING RELEASE: $repo is a explicitly prohibited"
                            }
                        }
                    } 
                    else {
                        Write-Information "SKIPPING RELEASE: Found pending update branches in $repo"
                    }
                }
                else {
                    Write-Information "SKIPPING RELEASE: $skippingReason : $autoUpdateCount"
                }
            }
            else {
                Write-Information "SKIPPING RELEASE: $repo is a template"
            }
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

Write-Information ""
Write-Information "***************************************************************"
Write-Information "***************************************************************"
Write-Information ""

dotnet tool restore

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

Write-Information ">>>>>>>>>>>> ALL REPOS PROCESSED <<<<<<<<<<<<"

