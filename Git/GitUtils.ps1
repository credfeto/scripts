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


function commit($message) {
    git add -A
    git commit -m"$message"
}

function push()
{
    git push
}

function loadRepoList($repoFile) {
   return Get-Content $repos | Select-Object
}