function Release-Create {
param(
    [string]$repo, 
    [string]$changeLog, 
    [string]$repoPath
)
     $nextPatch = BuildVersion-GetNextPatch
     if($nextPatch) {
#         ChangeLog-CreateRelease -fileName $changeLog -release $nextPatch
#         Git-Commit -message "Release notes for $nextPatch"
#         Git-Push --repoPath  $repoPath
# 
         $branch = "release/$nextPatch"
         Write-Information "MAKERELEASE: Should have created branch: $branch"

#         $branched = Git-CreateBranch -branchName $branch -repoPath $repoPath
#         if($branch) {
#             Git-PushOrigin -branchName $branch -repoPath $repoPath
#             Write-Information "*** Created new release branch $branch in $repo"
#         }
     }
}




Export-ModuleMember -Function Release-Create