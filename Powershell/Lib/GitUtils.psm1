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
    git reset HEAD --hard
    git clean -f -x -d
    git checkout master
    git reset HEAD --hard
    git clean -f -x -d
    git fetch

    # NOTE Loses all local commmits on master
    git reset --hard origin/master
    git remote update origin --prune
    git prune
    git gc --aggressive --prune

    Git-RemoveAllLocalBranches
}

function Git-HasUnCommittedChanges {
    git diff --no-patch --exit-code
    if(!$?) {
        return $true
    }

    return $false
}

function Git-GetFolderForRepo {
param(
    [string] $repo
    )

    # Extract the folder from the repo name
    [string] $folder = $repo.Substring($repo.LastIndexOf("/")+1)
    $folder = $folder.SubString(0, $folder.LastIndexOf("."))

    return $folder
}

function Git-EnsureSynchronised {
param(
    [string] $repo, 
    [string] $repofolder
    )

    Write-Information "Repo: $repo"
    Write-Information "Folder: $repofolder"

    $gitHead = Join-Path -Path $repoFolder -ChildPath ".git" 
    $gitHead = Join-Path -Path $gitHead -ChildPath "HEAD" 
    
    Write-Information "Head: $gitHead"

    $gitHeadCloned = Test-Path -path $gitHead

    if ($gitHeadCloned -eq $True) {
        Write-Information "Already Cloned"
        Set-Location -Path $repofolder

        Git-ResetToMaster
    }
    else
    {
        Write-Information "Cloning..."
        git clone $repo
        Set-Location -Path $repofolder
    }
}

function Git-Commit {
param(
    [string] $message
    )
    
    git add -A
    git commit -m"$message"
}

function Git-Commit-Named {
param(
    [string] $message,
    [String[]] $files
    )
    

    foreach($file in $files) {
        $fileUnix = $file.Replace("\", "/")
        Write-Information "Staging $fileUnix"
        git add $fileUnix
    }

    
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
    if($result -eq $null) {
	return $false;
    }
    $result = $result.Trim()
    if($result -eq $branchName) {
        return $true
    }

    if($result -eq "origin/$branchName") {
        return $true
    }

    return $false
}

function Git-CreateBranch {
param(
    [string] $branchName
    )

    $branchExists = Git-DoesBranchExist -branchName $branchName
    if($branchExists -eq $true) {
        Write-Information "Failed to create branch $branchName - branch already exists"
        return $false
    }

    git checkout -b $branchName
    if(!$?) {
        Write-Information "Failed to create branch $branchName - Create branch failed - Call failed."
        return $false
    }

    Write-Information "Created branch $branchName"

    return $true;
}

function Git-Get-HeadRev {
    $result = git rev-parse --short HEAD

    if(!$?) {
        Write-Information "Failed to create branch $branchName - Create branch failed - Call failed."
        return $null
    }

    return $result.Trim()
}

$rev = Git-GetHeadHash



function Git-LoadRepoList {
param(
    [string] $repoFile
    )

    [string[]] $content = Get-Content -Path $repoFile

    return $content
}


Export-ModuleMember -Function Git-RemoveAllLocalBranches
Export-ModuleMember -Function Git-ResetToMaster
Export-ModuleMember -Function Git-EnsureSynchronised
Export-ModuleMember -Function Git-HasUnCommittedChanges
Export-ModuleMember -Function Git-Commit
Export-ModuleMember -Function Git-Commit-Named
Export-ModuleMember -Function Git-CreateBranch
Export-ModuleMember -Function Git-Push
Export-ModuleMember -Function Git-PushOrigin
Export-ModuleMember -Function Git-DoesBranchExist
Export-ModuleMember -Function Git-LoadRepoList
Export-ModuleMember -Function Git-GetFolderForRepo
Export-ModuleMember -Function Git-Get-HeadRev