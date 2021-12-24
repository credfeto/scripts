$env:GIT_REDIRECT_STDERR="2>&1"

function Git-Log {
param(
    [string[]]$result
    )
    
    foreach($line in $result) {
        Write-Information $line
    }
}

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
    
    Write-Information "Using Repo: $repoPath"
    
    return $repoPath
}


function Git-GetRemoteBranches {
param(
        [string] $repoPath,
        [string] $upstream = "origin"
    )

    [string]$repoPath = GetRepoPath -repoPath $repoPath

    [string[]]$result = git -C $repoPath branch --remote 2>&1

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

    [string[]]$result = git -C $repoPath branch 2>&1
    foreach($item in $result) {
        [string]$branch = $item.Trim()
        if(!$branch.StartsWith("* ")) {
            $complete = git -C $repoPath branch -d $branch 2>&1
        }
    }
}

function Git-ResetToMaster {
param(
        [string] $repoPath
    )

    [string]$repoPath = GetRepoPath -repoPath $repoPath

    $head = Git-Get-HeadRev -repoPath $repoPath
    
    # junk any existing checked out files
    & git -C $repoPath reset HEAD --hard | Out-Null
    & git -C $repoPath clean -f -x -d | Out-Null
    & git -C $repoPath checkout master | Out-Null
    & git -C $repoPath reset HEAD --hard | Out-Null
    & git -C $repoPath clean -f -x -d | Out-Null
    & git -C $repoPath fetch | Out-Null
    
    # NOTE Loses all local commits on master
    & git -C $repoPath reset --hard origin/master | Out-Null
    & git -C $repoPath remote update origin --prune | Out-Null
    & git -C $repoPath prune | Out-Null
    
    $newHead = Git-Get-HeadRev -repoPath $repoPath
    if($head -ne $newHead) {
        # ONLY GC if head is different, i.e. something has changed    
        & git -C $repoPath gc --aggressive --prune | Out-Null
    }

    Git-RemoveAllLocalBranches -repoPath $repoPath
    
    return $newHead
}

function Git-HasUnCommittedChanges {
param(
    [string] $repoPath
    )

    [string]$repoPath = GetRepoPath -repoPath $repoPath

    $result = git -C $repoPath diff --no-patch --exit-code 2>&1
    if(!$?) {
        Git-Log -result $result
        return $true
    }
    
    Git-Log -result $result
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

        Git-ResetToMaster -repoPath $repoFolder
    }
    else
    {
        Write-Information "Cloning..."
        $result = git clone $repo --recurse-submodules 2>&1 
        Git-Log -result $result
        Set-Location -Path $repofolder
    }
}

function Git-Commit {
param(
    [string] $repoPath,
    [string] $message
    )

    [string]$repoPath = GetRepoPath -repoPath $repoPath

    & git -C $repoPath add -A | Out-Null
    & git -C $repoPath commit -m"$message" | Out-Null
}

function Git-Commit-Named {
param(
    [string] $repoPath,
    [string] $message,
    [String[]] $files
    )

    [string]$repoPath = GetRepoPath -repoPath $repoPath

    foreach($file in $files) {
        [string]$fileUnix = $file.Replace("\", "/")
        Write-Information "Staging $fileUnix"
        & git -C $repoPath add $fileUnix | Out-Null
    }

    & git -C $repoPath commit -m"$message" | Out-Null
}

function Git-Push {
param(
    [string] $repoPath
    )

    [string]$repoPath = GetRepoPath -repoPath $repoPath

    & git -C $repoPath push | Out-Null
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

    & git -C $repoPath push --set-upstream origin $branchName -v | Out-Null
}


function Git-DoesBranchExist {
param(
    [string] $branchName,
    [string] $repoPath
    )

    [string]$repoPath = GetRepoPath -repoPath $repoPath

    $result = git -C $repoPath branch --remote 2>&1

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

    $result = git -C $repoPath checkout -b $branchName 2>&1
    if(!$?) {
        Git-Log -result $result
        Write-Information "Failed to create branch $branchName - Create branch failed - Call failed."
        return $false
    }

    Git-Log -result $result
    Write-Information "Created branch $branchName"

    return $true;
}

function Git-DeleteBranch {
param(
    [string] $branchName,
    [string] $repoPath
    )

    [string]$repoPath = GetRepoPath -repoPath $repoPath

    [bool]$branchExists = Git-DoesBranchExist -branchName $branchName -repoPath $repoPath
    if($branchExists) {
        & git -C $repoPath branch -D $branchName | Out-Null
    }
    
    [bool]$branchExists = Git-DoesBranchExist -branchName "origin/$branchName" -repoPath $repoPath
    if($branchExists) {
        & git -C $repoPath push origin ":$branchName" | Out-Null
    }

    return $true;
}

function Git-ReNormalise {
param(
        [string] $repoPath
    )

    [string]$repoPath = GetRepoPath -repoPath $repoPath
    
    & git -C $repoPath add . --renormalize | Out-Null
    [bool]$hasChanged = Git-HasUnCommittedChanges -repoPath $repoPath
    if($hasChanged -eq $true) {
        & git -C $repoPath commit -m"Renormalised files" | Out-Null
        & git -C $repoPath push | Out-Null
    }
}


function Git-Get-HeadRev {
param(
    [string] $repoPath
    )

    [string]$repoPath = GetRepoPath -repoPath $repoPath
    
    $result = git -C $repoPath rev-parse HEAD 2>&1    

    if(!$?) {
        Git-Log -result $result
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

    $result = git -C $repoPath submodule 2>&1

    if(!$?) {
        Git-Log -result $result
        Write-Information "Failed to get submodules."
        return $false
    }

    if($result -eq $null -or $result.Trim() -eq "")  {
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

function Get-GetLastCommitDate {
param(
    [string] $repoPath
    )

    [string]$repoPath = GetRepoPath -repoPath $repoPath

    $unixTime = git -C $repoPath log -1 --format=%ct 2>&1

    [DateTime]$when = [DateTimeOffset]::FromUnixTimeSeconds($unixTime).UtcDateTime

    return $when
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
Export-ModuleMember -Function Get-GetLastCommitDate