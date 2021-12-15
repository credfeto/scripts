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
    
    Write-Information "$repo => Create release $nextPatch"
    #throw "Not Creating releases"
    
    ChangeLog-CreateRelease -fileName $changeLog -release $nextPatch
    Git-Commit -message "Release notes for $nextPatch"
    Git-Push -repoPath  $repoPath
    
    [string]$branch = "release/$nextPatch"
    Write-Information "RELEASE: Should have created branch: $branch"
        
    [bool]$branched = Git-CreateBranch -branchName $branch -repoPath $repoPath
    if($branched) {
        Git-PushOrigin -branchName $branch -repoPath $repoPath
        Write-Information "*** Created new RELEASE branch $branch in $repo"
    } else {
        throw "Failed to create RELEASE branch $branch in $repo"
    }
}

Export-ModuleMember -Function Release-Create