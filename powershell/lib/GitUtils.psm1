$env:GIT_REDIRECT_STDERR="2>&1"

function GetRepoPath{
    param(
        [string] $repoPath
    )

    if([string]::IsNullOrWhiteSpace($repoPath)) {
        $currentDir = Get-Location
        return $currentDir.Path
    }
    else {
        return $repoPath
    }
}


function Git-GetRemoteBranches {
param(
        [string] $repoPath,
        [string] upstream = "origin"
    )

    $repoPath = GetRepoPath -repoPath $repoPath

    $result = git -C $repoPath branch --remote

    $branches = @()

    $remotePrefix = "$upstream/"
    
    foreach($branch in $result) {
        $branch = $branch.Trim()
        if(!$branch.StartsWith($remotePrefix)) {
                continue
        }

        $branch = $branch.SubString(7)

        $branch = $branch.Split(" ")[0]
        if($branch -eq "HEAD") {
                continue
        }

        $branches += $branch
    }

    return $branches
}

function Git-RemoveAllLocalBranches {
param(
        [string] $repoPath
    )

    $repoPath = GetRepoPath -repoPath $repoPath

    $result = git -C $repoPath branch
    foreach($branch in $result) {
        $branch = $branch.Trim()
        if(!$branch.StartsWith("* ")) {
            git branch -d $branch
        }
    }
}

function Git-ResetToMaster {
param(
        [string] $repoPath
    )

    $repoPath = GetRepoPath -repoPath $repoPath

    # junk any existing checked out files
    git -C $repoPath reset HEAD --hard
    git -C $repoPath clean -f -x -d
    git -C $repoPath checkout master
    git -C $repoPath reset HEAD --hard
    git -C $repoPath clean -f -x -d
    git -C $repoPath fetch

    # NOTE Loses all local commmits on master
    git -C $repoPath reset --hard origin/master
    git -C $repoPath remote update origin --prune
    git -C $repoPath prune
    git -C $repoPath gc --aggressive --prune

    Git-RemoveAllLocalBranches -repoPath $repoPath
}

function Git-HasUnCommittedChanges {
param(
    [string] $repoPath
    )

    $repoPath = GetRepoPath -repoPath $repoPath

    git -C $repoPath diff --no-patch --exit-code
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
        git clone $repo --recurse-submodules
        Set-Location -Path $repofolder
    }
}

function Git-Commit {
param(
    [string] $message
    )

    $repoPath = GetRepoPath -repoPath $repoPath

    git -C $repoPath add -A
    git -C $repoPath commit -m"$message"
}

function Git-Commit-Named {
param(
    [string] $message,
    [String[]] $files,
    [string] $repoPath
    )

    $repoPath = GetRepoPath -repoPath $repoPath

    foreach($file in $files) {
        $fileUnix = $file.Replace("\", "/")
        Write-Information "Staging $fileUnix"
        git -C $repoPath add $fileUnix
    }

    
    git commit -m"$message"
}

function Git-Push() {
param(
    [string] $repoPath
    )

    $repoPath = GetRepoPath -repoPath $repoPath

    git -C $repoPath push
}

function Git-PushOrigin {
param(
    [string] $branchName,
    [string] $repoPath
    )
    
    if($branchName -eq $null) {
        throw "Invalid branch (null)"
    }

    if($branchName -eq "") {
        throw "Invalid branch: [$branchName]"
    }

    $repoPath = GetRepoPath -repoPath $repoPath

    git -C $repoPath push --set-upstream origin $branchName -v
}


function Git-DoesBranchExist {
param(
    [string] $branchName,
    [string] $repoPath
    )

    $repoPath = GetRepoPath -repoPath $repoPath

    $result = git -C $repoPath branch --remote

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
    [string] $branchName,
    [string] $repoPath
    )

    $repoPath = GetRepoPath -repoPath $repoPath

    $branchExists = Git-DoesBranchExist -branchName $branchName -repoPath $repoPath
    if($branchExists -eq $true) {
        Write-Information "Failed to create branch $branchName - branch already exists"
        return $false
    }

    git -C $repoPath checkout -b $branchName
    if(!$?) {
        Write-Information "Failed to create branch $branchName - Create branch failed - Call failed."
        return $false
    }

    Write-Information "Created branch $branchName"

    return $true;
}

function Git-DeleteBranch {
param(
    [string] $branchName,
    [string] $repoPath
    )

    $repoPath = GetRepoPath -repoPath $repoPath

    git -C $repoPath branch -d $branchName
    git -C $repoPath push origin ":$branchName"

    return $true;
}

function Git-ReNormalise {
param(
        [string] $repoPath
    )

    $repoPath = GetRepoPath -repoPath $repoPath
    
    git -C $repoPath add . --renormalize
    $hasChanged = Git-HasUnCommittedChanges -repoPath $repoPath
    if($hasChanged -eq $true) {
        git -C $repoPath commit -m"Renormalised files"
        git -C $repoPath push
    }
}


function Git-Get-HeadRev {
param(
    [string] $repoPath
    )

    $repoPath = GetRepoPath -repoPath $repoPath
    
    $result = git -C $repoPath rev-parse HEAD    

    if(!$?) {
        Write-Information "Failed to get head rev"
        return $null
    }

    return $result.Trim()
}

function Git-HasSubmodules {
    param(
        [string] $repoPath
    )

    $repoPath = GetRepoPath -repoPath $repoPath

    $result = git -C $repoPath submodule

    if(!$?) {
        Write-Information "Failed to get submodules."
        return $false
    }

    if($result -eq $null -or $result.Trim() -eq "")
    {
        return $false
    }
    
    Write-Information "Submodules found:"
    Write-Information $result

    return $true
}


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
Export-ModuleMember -Function Git-DeleteBranch
Export-ModuleMember -Function Git-Push
Export-ModuleMember -Function Git-PushOrigin
Export-ModuleMember -Function Git-DoesBranchExist
Export-ModuleMember -Function Git-LoadRepoList
Export-ModuleMember -Function Git-GetFolderForRepo
Export-ModuleMember -Function Git-Get-HeadRev
Export-ModuleMember -Function Git-ReNormalise
Export-ModuleMember -Function Git-HasSubmodules
Export-ModuleMember -Function Git-GetRemoteBranches