function resetToMaster() {

    # junk any existing checked out files
    & $git reset head --hard
    & $git clean -f -x -d
    & $git checkout master
    & $git reset head --hard
    & $git clean -f -x -d
    & $git fetch

    # NOTE Loses all local commmits on master
    & $git reset --hard origin/master
    & $git remote update origin --prune
    & $git prune
    & $git gc --aggressive --prune
}

function ensureSynchronised($repo, $repofolder) {

    $githead = Join-Path -Path $repoFolder -ChildPath ".git" 
    $githead = Join-Path -Path $githead -ChildPath "HEAD" 
    
    Write-Host $githead
    $gitHeadCloned = Test-Path -path $githead

    if ($gitHeadCloned -eq $True) {
        Write-Host "Already Cloned"
        Set-Location $repofolder

        resetToMaster
    }
    else
    {
        & $git clone $repo        
    }
}

function createBranch($branchName) {
    $out = git checkout -b $branchName
    $exit = $?
    if($exit -ne 0) {
        Write-Host "Failed to create branch $branchName"
        Write-Host $out
        Write-Host "Exit: $exit"
        return $false;
    }
    
    return $true;
}

function commit($message) {
    & $git  add -A
    & $git commit -m"$message"
}

function push() 
{
    & $git push
}

function pushOrigin($branchName) {
    if($branchName -eq $null) {
        throw "Invalid branch (null)"
    }

    if($branchName -eq "") {
        throw "Invalid branch: [$branchName]"
    }

    git push --set-upstream origin $branchName -v
}


function loadRepoList($repoFile) {
   return Get-Content $repos | Select-Object
}

function doesBranchExist($branchName) {
    $result = git branch --remote

    $regex = $branchName.replace(".", "\.") + "$"

    $result -match $regex
    $result = $result.Trim()
    if($result -eq $branchName) {
        return $true
    }

    if($result -eq "origin/$branchName") {
        return $true
    }

    return $false
}