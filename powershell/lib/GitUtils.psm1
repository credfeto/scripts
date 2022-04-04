$env:GIT_REDIRECT_STDERR="2>&1"

function Git-Log {
param(
    [string[]]$result
    )
    
    foreach($line in $result) {
        Write-Information $line
    }
}

function Git-ValidateBranchName {
param (
    [string] $branchName = $(throw "Git-ValidateBranchName: branchName not specified"),
    [string] $method = $(throw "Git-ValidateBranchName: method not specified")
    
)

    if($branchName -eq $null) {
        throw "$($method) : Invalid branch (null)"
    }

    if($branchName -eq "") {
        throw "$($method) : Invalid branch: [$branchName]"
    }

    if($branchName.Contains("//")) {
        throw "$($method) : Invalid branch: [$branchName]"
    }
}

function GetRepoPath {
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


function Git-GetDefaultBranch {
param(
    [string] $repoPath = $(throw "Get-GetDefaultBranch: repoPath not specified"),
    [string] $upstream = "origin"
    )

    [string]$repoPath = GetRepoPath -repoPath $repoPath

    [string[]]$result = git -C $repoPath remote show $upstream
    
    [string] $branch =  $result | Select-String -Pattern 'HEAD branch: (.*)' -CaseSensitive | %{$_.Matches.Groups[1].value}
    
    return $branch.Trim()
}

function Git-GetRemoteBranches {
param(
        [string] $repoPath = $(throw "Git-GetRemoteBranches: repoPath not specified"),
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
        [string] $repoPath = $(throw "Git-RemoveAllLocalBranches: repoPath not specified")
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
        [string] $repoPath = $(throw "Git-ResetToMaster: repoPath not specified")
    )

    [string]$upstream = "origin";
    [string]$repoPath = GetRepoPath -repoPath $repoPath

    $head = Git-Get-HeadRev -repoPath $repoPath
    
    [string]$defaultBranch = Git-GetDefaultBranch -repoPath $repoPath -upstream $upstream
    [string]$upstreamBranch = "$upstream/$defaultBranch"
    
    # junk any existing checked out files
    & git -C $repoPath reset HEAD --hard | Out-Null
    & git -C $repoPath clean -f -x -d | Out-Null
    & git -C $repoPath checkout $defaultBranch | Out-Null
    & git -C $repoPath reset HEAD --hard | Out-Null
    & git -C $repoPath clean -f -x -d | Out-Null
    & git -C $repoPath fetch --recurse-submodules | Out-Null
    
    # NOTE Loses all local commits on master
    & git -C $repoPath reset --hard $upstreamBranch | Out-Null
    & git -C $repoPath remote update $upstream --prune | Out-Null
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
    [string] $repoPath = $(throw "Git-HasUnCommittedChanges: repoPath not specified")
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
    [string] $repo = $(throw "Git-GetFolderForRepo: repo not specified")
    )

    # Extract the folder from the repo name
    [string] $folder = $repo.Substring($repo.LastIndexOf("/")+1)
    $folder = $folder.SubString(0, $folder.LastIndexOf("."))

    return $folder
}

function Git-EnsureSynchronised {
param(
    [string] $repo = $(throw "Git-EnsureSynchronised: repo not specified"), 
    [string] $repoFolder = $(throw "Git-EnsureSynchronised: repoFolder not specified")
    )

    Write-Information "Repo: $repo"
    Write-Information "Folder: $repoFolder"

    [string]$gitHead = Join-Path -Path $repoFolder -ChildPath ".git" 
    [string]$gitHead = Join-Path -Path $gitHead -ChildPath "HEAD" 
    
    Write-Information "Head: $gitHead"

    [bool]$gitHeadCloned = Test-Path -path $gitHead

    if ($gitHeadCloned -eq $True) {
        Write-Information "Already Cloned"
        Set-Location -Path $repoFolder

        Git-ResetToMaster -repoPath $repoFolder
    }
    else
    {
        Write-Information "Cloning..."
        $result = git clone $repo --recurse-submodules 2>&1 
        Git-Log -result $result
        Set-Location -Path $repoFolder
    }
}

function Git-Commit {
param(
    [string] $repoPath = $(throw "Git-Commit: repoPath not specified"),
    [string] $message = $(throw "Git-Commit: message not specified")
    )

    [string]$repoPath = GetRepoPath -repoPath $repoPath

    & git -C $repoPath add -A | Out-Null
    & git -C $repoPath commit -m"$message" | Out-Null
}

function Git-Commit-Named {
param(
    [string] $repoPath = $(throw "Git-Commit-Named: repoPath not specified"),
    [string] $message = $(throw "Git-Commit-Named: message not specified"),
    [String[]] $files = $(throw "Git-Commit-Named: files not specified")
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
    [string] $repoPath = $(throw "Git-Push: repoPath not specified")
    )

    [string]$repoPath = GetRepoPath -repoPath $repoPath

    & git -C $repoPath push | Out-Null
}


function Git-PushOrigin {
param(
    [string] $repoPath = $(throw "Git-PushOrigin: repoPath not specified"),
    [string] $branchName = $(throw "Git-PushOrigin: branchName not specified")
    )
    
    [string]$upstream = "origin";

    Git-ValidateBranchName -branchName $branchName -method "Git-PushOrigin"

    [string]$repoPath = GetRepoPath -repoPath $repoPath

    & git -C $repoPath push --set-upstream $upstream $branchName -v | Out-Null
}


function Git-DoesBranchExist {
param(
    [string] $repoPath = $(throw "Git-DoesBranchExist: repoPath not specified"),
    [string] $branchName = $(throw "Git-DoesBranchExist: branchName not specified")
    )
    
    [string]$upstream = "origin";
    [string]$repoPath = GetRepoPath -repoPath $repoPath

    [string]$defaultBranch = Git-GetDefaultBranch -repoPath $repoPath -upstream $upstream
    [string]$upstreamBranch = "$upstream/$defaultBranch"

    Git-ValidateBranchName -branchName $branchName -method "Git-DoesBranchExist"

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

    [string]$upstreamBranch = "$upstream/$branchName"
    if($result -eq $upstreamBranch) {
        return $true
    }

    return $false
}

function Git-CreateBranch {
param(
    [string] $repoPath = $(throw "Git-CreateBranch: repoPath not specified"),
    [string] $branchName = $(throw "Git-CreateBranch: branchName not specified")
    )
    
    Git-ValidateBranchName -branchName $branchName -method "Git-CreateBranch"

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
    [string] $repoPath = $(throw "Git-DeleteBranch: repoPath not specified"),
    [string] $branchName = $(throw "Git-DeleteBranch: branchName not specified")
    )

    [string]$upstream = "origin"

    Git-ValidateBranchName -branchName $branchName -method "Git-DeleteBranch"

    [string]$repoPath = GetRepoPath -repoPath $repoPath

    [bool]$branchExists = Git-DoesBranchExist -branchName $branchName -repoPath $repoPath
    if($branchExists) {
        & git -C $repoPath branch -D $branchName | Out-Null
    }
    
    [string]$upstreamBranch = "$upstream/$branchName"
    [bool]$branchExists = Git-DoesBranchExist -branchName $upstreamBranch -repoPath $repoPath
    if($branchExists) {
        & git -C $repoPath push $upstream ":$branchName" | Out-Null
    }

    return $true;
}

function Git-ReNormalise {
param(
    [string] $repoPath = $(throw "Git-ReNormalise: repoPath not specified")
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
    [string] $repoPath = $(throw "Git-Get-HeadRev: repoPath not specified")
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
    [string] $repoPath = $(throw "Git-HasSubmodules: repoPath not specified")
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

function Git-RemoveBranchesForPrefix {
param(
    [string]$repoPath = $(throw "Git-RemoveBranchesForPrefix: repoPath not specified"), 
    [string]$branchForUpdate = $(throw "Git-RemoveBranchesForPrefix: branchForUpdate not specified"), 
    [string]$branchPrefix = $(throw "Git-RemoveBranchesForPrefix: branchPrefix not specified")
    )

    [string]$upstream = "origin"
    
    Git-ValidateBranchName -branchName $branchPrefix -method "Git-RemoveBranchesForPrefix"

    [string[]]$remoteBranches = Git-GetRemoteBranches -repoPath $repoFolder -upstream $upstream
    
    Write-Information "Looking for branches to remove based on prefix: $branchPrefix"        
    foreach($branch in $remoteBranches) {
        if($branchForUpdate) {
            if($branch -eq $branchForUpdate) {
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
    [string] $repoPath = $(throw "Get-GetLastCommitDate: repoPath not specified")
    )

    [string]$repoPath = GetRepoPath -repoPath $repoPath

    $unixTime = git -C $repoPath log -1 --format=%ct 2>&1

    [DateTime]$when = [DateTimeOffset]::FromUnixTimeSeconds($unixTime).UtcDateTime

    return $when
}

function Git-LoadRepoList {
param(
    [string] $repoFile = $(throw "Git-LoadRepoList: repoPath not specified")
    )

    [string[]] $content = Get-Content -Path $repoFile

    return $content
}

Export-ModuleMember -Function Git-GetDefaultBranch
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
