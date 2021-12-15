function Release-Create {
param(
    [string]$repo, 
    [string]$changeLog, 
    [string]$repoPath
)
    Write-Information "Looking for next RELEASE version"
    [string]$nextPatch = BuildVersion-GetNextPatch
    if([string]::IsNullOrEmpty($nextPatch)) {
        throw "No RELEASE version found for $repo"
    }
    
    if($nextPatch.StartsWith("0.")) {
        Write-Information "NOT CREATING RELEASE as version is 0.x.y"
        return
    }
    
    Write-Information "$repo => Create release $nextPatch"
    throw "Not Creating releases"
    
    ChangeLog-CreateRelease -fileName $changeLog -release $nextPatch
    Git-Commit -message "Release notes for $nextPatch"
    Git-Push -repoPath  $repoPath
    
    [string]$branch = "release/$nextPatch"
    Write-Information "RELEASE: Should have created branch: $branch"
        
    [bool]$branched = Git-CreateBranch -branchName $branch -repoPath $repoPath
    if($branched) {
        Git-PushOrigin -branchName $branch -repoPath $repoPath
        Write-Information "*** Created new RELEASE branch $branch in $repo"
        
        throw "Abort run as release created - may affect other packages"
    } else {
        throw "Failed to create RELEASE branch $branch in $repo"
    }
}

Export-ModuleMember -Function Release-Create