$env:GIT_REDIRECT_STDERR="2>&1"

function GetRepoPath{
    param(
        [string] $repoPath
    )

    if([string]::IsNullOrWhiteSpace($repoPath)) {
        $currentDir = Get-Location
        $repoPath = $currentDir.Path
    }
    
    if([string]::IsNullOrWhiteSpace($repoPath)) {
        throw "Could not determine repo path"
    }
    
    return $repoPath
}


function Git-GetRemoteBranches {
param(
        [string] $repoPath,
        [string] $upstream = "origin"
    )

    [string]$repoPath = GetRepoPath -repoPath $repoPath

    [string[]]$result = git -C $repoPath branch --remote

    $branches = @()

    [string]$remotePrefix = "$upstream/"
    
    Write-Information "Looking for Remote Branches for : $remotePrefix"
    
    foreach($item in $result) {
        [string]$branch = $item.Trim()
        if(!$branch.StartsWith($remotePrefix)) {
            Write-Information "- Skipping $branch"
            continue
        }

        $branch = $branch.SubString($remotePrefix.Length)
        $branch = $branch.Split(" ")[0]
        if($branch -eq "HEAD") {
            Write-Information "- Skipping $branch"
            continue
        }

        Write-Information "+ Found $upstream/$branch"
        $branches += $branch
    }

    return [string[]]$branches
}

function Git-RemoveAllLocalBranches {
param(
        [string] $repoPath
    )

    [string]$repoPath = GetRepoPath -repoPath $repoPath

    [string[]]$result = git -C $repoPath branch
    foreach($item in $result) {
        [string]$branch = $item.Trim()
        if(!$branch.StartsWith("* ")) {
            $complete = git -C $repoPath branch -d $branch
        }
    }
}

function Git-ResetToMaster {
param(
        [string] $repoPath
    )

    [string]$repoPath = GetRepoPath -repoPath $repoPath

    # junk any existing checked out files
    git -C $repoPath reset HEAD --hard
    git -C $repoPath clean -f -x -d
    git -C $repoPath checkout master
    git -C $repoPath reset HEAD --hard
    git -C $repoPath clean -f -x -d
    git -C $repoPath fetch

    # NOTE Loses all local commits on master
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

    [string]$repoPath = GetRepoPath -repoPath $repoPath

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

    [string]$gitHead = Join-Path -Path $repoFolder -ChildPath ".git" 
    [string]$gitHead = Join-Path -Path $gitHead -ChildPath "HEAD" 
    
    Write-Information "Head: $gitHead"

    [bool]$gitHeadCloned = Test-Path -path $gitHead

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

    [string]$repoPath = GetRepoPath -repoPath $repoPath

    git -C $repoPath add -A
    git -C $repoPath commit -m"$message"
}

function Git-Commit-Named {
param(
    [string] $message,
    [String[]] $files,
    [string] $repoPath
    )

    [string]$repoPath = GetRepoPath -repoPath $repoPath

    foreach($file in $files) {
        [string]$fileUnix = $file.Replace("\", "/")
        Write-Information "Staging $fileUnix"
        git -C $repoPath add $fileUnix
    }

    git -C $repoPath commit -m"$message"
}

function Git-Push() {
param(
    [string] $repoPath
    )

    [string]$repoPath = GetRepoPath -repoPath $repoPath

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

    [string]$repoPath = GetRepoPath -repoPath $repoPath

    git -C $repoPath push --set-upstream origin $branchName -v
}


function Git-DoesBranchExist {
param(
    [string] $branchName,
    [string] $repoPath
    )

    [string]$repoPath = GetRepoPath -repoPath $repoPath

    $result = git -C $repoPath branch --remote

    [string]$regex = $branchName.replace(".", "\.") + "$"

    $result -match $regex
    if($result -eq $null) {
	return $false;
    }
    
    [string]$result = $result.Trim()
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

    [string]$repoPath = GetRepoPath -repoPath $repoPath

    [bool]$branchExists = Git-DoesBranchExist -branchName $branchName -repoPath $repoPath
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

    [string]$repoPath = GetRepoPath -repoPath $repoPath

    $deleted = git -C $repoPath branch -D $branchName
    $deleted = git -C $repoPath push origin ":$branchName"

    return $true;
}

function Git-ReNormalise {
param(
        [string] $repoPath
    )

    [string]$repoPath = GetRepoPath -repoPath $repoPath
    
    git -C $repoPath add . --renormalize
    [bool]$hasChanged = Git-HasUnCommittedChanges -repoPath $repoPath
    if($hasChanged -eq $true) {
        git -C $repoPath commit -m"Renormalised files"
        git -C $repoPath push
    }
}


function Git-Get-HeadRev {
param(
    [string] $repoPath
    )

    [string]$repoPath = GetRepoPath -repoPath $repoPath
    
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

    [string]$repoPath = GetRepoPath -repoPath $repoPath

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

function Git-RemoveBranchesForPrefix{
param(
    [string]$repoPath, 
    [string]$branchForUpdate, 
    [string]$branchPrefix)

    [string[]]$remoteBranches = Git-GetRemoteBranches -repoPath $repoFolder -upstream "origin"
    
    Write-Information "Looking for branches to remove based on prefix: $branchPrefix"        
    foreach($branch in $remoteBranches) {
        if($branchForUpdate) {
            if($branch -eq $branchName) {
                Write-Information "- Skipping branch just pushed to: $branch"
                continue
            }
        }
        
        if($branch.StartsWith($branchPrefix)) {
            Write-Information "+ Deleting older branch for package: $branch"
            Git-DeleteBranch -branchName $branch -repoPath $repoFolder
        }
    }        
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
Export-ModuleMember -Function Git-RemoveBranchesForPrefix