function Release-Create {
param(
    [string]$repo = $(throw "Release-Create: repo not specified"), 
    [string]$changeLog = $(throw "Release-Create: changeLog not specified"), 
    [string]$repoPath = $(throw "Release-Create: repoPath not specified")
)
    Log -message "Looking for next RELEASE version"
    [string]$nextPatch = BuildVersion-GetNextPatch
    if([string]::IsNullOrEmpty($nextPatch)) {
        throw "No RELEASE version found for $repo"
    }
    
    if($nextPatch.StartsWith("0.")) {
        Log -message "NOT CREATING RELEASE as version is 0.x.y"
        return
    }
    
    Log -message "$repo => Create release $nextPatch"
    #throw "Not Creating releases"
    
    ChangeLog-CreateRelease -fileName $changeLog -release $nextPatch
    Git-Commit -repoPath $repoPath -message "Release notes for $nextPatch"
    Git-Push -repoPath $repoPath
    
    [string]$branch = "release/$nextPatch"
    Log -message "RELEASE: Should have created branch: $branch"
        
    [bool]$branched = Git-CreateBranch -branchName $branch -repoPath $repoPath
    if($branched) {
        Git-PushOrigin -branchName $branch -repoPath $repoPath
        Log -message "*** Created new RELEASE branch $branch in $repo"
        
        throw "Abort run as release created - may affect other packages"
    } else {
        throw "Failed to create RELEASE branch $branch in $repo"
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

    if($repo.Contains("funfair-build-check")) {
        return $true
    }

    if($repo.Contains("funfair-build-version")) {
        return $true
    }
    
    if($repo.Contains("funfair-content-package-builder")) {
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
                Log -message "IGNORING $packageId for update"
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

    [string]$expr = "(?ms)" + "^\s*\-\s*Dependencies\s*\-\sUpdated\s+(?<PackageId>.+(\.+)*?)\sto\s+(\d+\..*)$"
    
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
                Log -message "Found Matching Update: $packageName"
                $updateCount += 1
            } else {
                Log -message "Skipping Ignored Update: $packageName"
            }
            continue
        }

        if($line -match "^\s*\-\s*GEOIP\s*\-\s*") {
            # GEO-IP update
            $updateCount += 1
            continue
        }
        
        if($line.StartsWith("- SDK - Updated DotNet SDK to ")) {
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
            if(!$branch.EndsWith("/preview")) {
                Log -message "Found dependency branch: $branch"
                return $true
            }
        }

#         if($branch.StartsWith("dependabot/")) {
#             Log -message "Found dependency update branch: $branch"
#             return $true
#         }
    }
    
    return $false
}

function CheckRepoForAllowedAutoUpgrade {
param (
    [string]$repo = $(throw "CheckRepoForAllowedAutoUpgrade: repo not specified")
    )
    
    Log -message "Checking if can auto-upgrade $repo..."
    if($repo -eq "git@github.com:funfair-tech/funfair-server-content-package.git") {
        return $false
    }
    
    if($repo.Contains("code-analysis")) {
        return $false
    }

    return $true
}


function Release-Skip {
    param(
    [string]$repo = $(throw "Release-Skip: repo not specified"),
    [string]$message = $(throw "Release-Skip: message not specified") 
)
    Log -message "SKIPPING RELEASE: $repo $message"
}

function Release-TryCreateNextPatch {
    param(
    [string]$repo = $(throw "Release-TryCreateNextPatch: repo not specified"), 
        [string]$changeLog = $(throw "Release-TryCreateNextPatch: changeLog not specified"), 
        [string]$repoPath = $(throw "Release-TryCreateNextPatch: repoPath not specified")
    )

# Settings for auto-release - could be passed in as parameters    
[int]$autoReleasePendingPackages = 2
[double]$minimumHoursBeforeAutoRelease = 4
[double]$inactivityHoursBeforeAutoRelease = 2 * $minimumHoursBeforeAutoRelease
    
    # *********************************************************
    # * 1 Template Repos

    Log -message "Checking if can create release for $repo"
            
    if($repo.Contains("template")) {
        Release-Skip -repo $repo -message "IS A TEMPLATE"
        return
    } 

    # *********************************************************
    # * 2 RELEASE NOTES AND DURATION
    
    Log -message "Processing Release Notes in $changeLog"
    
    [string[]]$releaseNotes = ChangeLog-GetUnreleased -fileName $changeLog
    Log-Batch -messages $releaseNotes
    [int]$autoUpdateCount = IsAllAutoUpdates -releaseNotes $releaseNotes -packages $packages
    
    Log -message "Checking Versions: Updated: $autoUpdateCount Trigger: $autoReleasePendingPackages"
    [DateTime]$lastCommitDate = Get-GetLastCommitDate -repoPath $repoFolder
    [DateTime]$now = [DateTime]::UtcNow                                    
    
    [TimeSpan]$durationTimeSpan = ($now - $lastCommitDate)
    $duration = $durationTimeSpan.TotalHours
    Log -message "Duration since last commit $duration hours"

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
                [string]$skippingReason = "RELEASING AFTER INACTIVITY : $autoUpdateCount"
            }
        }
    }

    if(!$shouldCreateRelease ) {
        Release-Skip -repo $repo -message "$skippingReason : $autoUpdateCount"
        return;
    }

    # *********************************************************
    # * 3 CODE QUALITY AND BUILD
        
    [string]$srcPath = Join-Path -Path $repoPath -ChildPath "src"
    [bool]$srcExists = Test-Path -Path $srcPath
    if($srcExists) {
        $projects = Get-ChildItem -Path $srcPath -Filter *.csproj -Recurse
        if ($projects.Length -gt 0) {
            # check solution builds
            [boolean]$okToRelease = DotNet-CheckSolution -srcFolder $srcPath -preRelease $false
            if(!$okToRelease) {
                Release-Skip -repo $repo -message "DOES NOT PASS RELEASE BUILD CHECKS!"
                return
            }
            
            [boolean]$okToRelease = DotNet-BuildSolution -srcFolder $srcPath
            if(!$okToRelease) {
                Release-Skip -repo $repo -message "DOES NOT BUILD!"
                return
            }
        }
    }
    
    # *********************************************************
    # * 4 Dispatch

    # At least $autoReleasePendingPackages auto updates... consider creating a release
    
    [bool]$hasPendingDependencyUpdateBranches = HasPendingDependencyUpdateBranches -repoPath $repoFolder
    if(!$hasPendingDependencyUpdateBranches) {            
        if (ShouldAlwaysCreatePatchRelease -repo $repo) {
            Log -message "**** MAKE RELEASE ****"
            Log -message "Changelog: $changeLog"
            Log -message "Repo: $repoFolder"
            Log -message "Reason: $skippingReason"
            Release-Create -repo $repo -changelog $changeLog -repoPath $repoFolder
        }
        else {
            $allowUpdates = CheckRepoForAllowedAutoUpgrade -repo $repo
            if($allowUpdates) {
                [bool]$publishable = DotNet-HasPublishableExe -srcFolder $srcPath
                if (!$publishable) {
                    Log -message "**** MAKE RELEASE ****"
                    Log -message "Changelog: $changeLog"
                    Log -message "Repo: $repoFolder"
                    Log -message "Reason: $skippingReason"
                    Release-Create -repo $repo -changelog $changeLog -repoPath $repoFolder
                }
                else {
                    if (ShouldAlwaysCreatePatchRelease -repo $repo) {
                        Log -message "**** MAKE RELEASE ****"
                        Log -message "Changelog: $changeLog"
                        Log -message "Repo: $repoFolder"
                        Log -message "Reason: $skippingReason"
                        Release-Create -repo $repo -changelog $changeLog -repoPath $repoFolder
                    }
                    else {
                        Release-Skip -repo $repo -message "CONTAINS PUBLISHABLE EXECUTABLES"
                    }
                }
            }
            else {
                Release-Skip -repo $repo -message "EXPLICITLY PROHIBITED"
            }
        }
    } 
    else {
        Release-Skip -repo $repo -message "FOUND PENDING UPDATE BRANCHES"
    }
}

Export-ModuleMember -Function Release-Skip
Export-ModuleMember -Function Release-Create
Export-ModuleMember -Function Release-TryCreateNextPatch
