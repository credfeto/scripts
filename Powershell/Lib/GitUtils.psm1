$env:GIT_REDIRECT_STDERR="2>&1"

function Git-RemoveAllLocalBranches {
    $result = git branch
    foreach($branch in $result) {
        $branch = $branch.Trim()
        if(!$branch.StartsWith("* ")) {
            git branch -d $branch
        }
    }
}

function Git-ResetToMaster {

    # junk any existing checked out files
    git reset head --hard
    git clean -f -x -d
    git checkout master
    git reset head --hard
    git clean -f -x -d
    git fetch

    # NOTE Loses all local commmits on master
    git reset --hard origin/master
    git remote update origin --prune
    git prune
    git gc --aggressive --prune

    Git-RemoveAllLocalBranches
}

function Git-EnsureSynchronised {
param(
    [string] $repo, 
    [string] $repofolder
    )

    $gitHead = Join-Path -Path $repoFolder -ChildPath ".git" 
    $gitHead = Join-Path -Path $gitHead -ChildPath "HEAD" 
    
    Write-Host $gitHead
    $gitHeadCloned = Test-Path -path $gitHead

    if ($gitHeadCloned -eq $True) {
        Write-Host "Already Cloned"
        Set-Location $repofolder

        Git-ResetToMaster
    }
    else
    {
        git clone $repo        
    }
}

function Git-CreateBranch {
param(
    [string] $branchName
    )

    git checkout -b $branchName
    if(!$?) {
        Write-Host "Failed to create branch $branchName"
        return $false;
    }
    
    return $true;
}

function Git-Commit {
param(
    [string] $message
    )

    git  add -A
    git commit -m"$message"
}

function Git-Push() 
{
    git push
}

function Git-PushOrigin {
param(
    [string] $branchName
    )
    
    if($branchName -eq $null) {
        throw "Invalid branch (null)"
    }

    if($branchName -eq "") {
        throw "Invalid branch: [$branchName]"
    }

    git push --set-upstream origin $branchName -v
}


function Git-DoesBranchExist {
param(
    [string] $branchName
    )

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


function Git-LoadRepoList {
param(
    [string] $repoFile
    )

    return Get-Content $repos | Select-Object
}

Export-ModuleMember -Function Git-RemoveAllLocalBranches
Export-ModuleMember -Function Git-ResetToMaster
Export-ModuleMember -Function Git-EnsureSynchronised
Export-ModuleMember -Function Git-CreateBranch
Export-ModuleMember -Function Git-Commit
Export-ModuleMember -Function Git-CreateBranch
Export-ModuleMember -Function Git-Push
Export-ModuleMember -Function Git-PushOrigin
Export-ModuleMember -Function Git-DoesBranchExist
Export-ModuleMember -Function Git-LoadRepoList