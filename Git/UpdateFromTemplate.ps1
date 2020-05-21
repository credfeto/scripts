#########################################################################

$ErrorActionPreference = "Stop" 
$templateRepo = "git@github.com:funfair-tech/funfair-server-template.git"
$repos = "repos.lst"
$root = Get-Location
$git="git"
Write-Host $root

$env:GIT_REDIRECT_STDERR="2>&1"

#########################################################################

# region Include required files
#
$ScriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
try {
    . ( Join-Path -Path $ScriptDirectory -ChildPath "DotNetTool.ps1")
    . (Join-Path -Path $ScriptDirectory -ChildPath "GitUtils.ps1")
    . (Join-Path -Path $ScriptDirectory -ChildPath "DotNetBuild.ps1")
    . (Join-Path -Path $ScriptDirectory -ChildPath "Changelog.ps1")
}
catch {
    Write-Host "Error while loading supporting PowerShell Scripts" 
}
#endregion

function updateFile($sourceRepo, $targetRepo, $filename) {
    Write-Host "Checking $filename"

    $srcPath = Join-Path -Path $sourceRepo -ChildPath $filename
    $trgPath = Join-Path -Path $targetRepo -ChildPath $filename

    $srcExists = Test-Path -Path $srcPath
    $trgExists = Test-Path -Path $trgPath

    if($srcExists -eq $true) {
        $srcHash = Get-FileHash -Path $srcPath -Algorithm SHA512
        $trgHash = Get-FileHash -Path $trgPath -Algorithm SHA512
        
        if($srcHash -ne $trgHash) {
            Write-Host "--- Copy"
            Copy-Item $srcPath -Destination $trgPath
            return $true
        }
    }
    elseif($trgExists -eq $true) {
        Write-Host "--- Delete"
        Remove-Item -Path $trgPath

        return $null
    }

    return $false;
}

function doCommit($fileName) {
    commit -message "[FF-1429] - Update $filename to match the template repo"
}

function updateFileAndCommit($sourceRepo, $targetRepo, $filename) {

    $ret = updateFile -sourceRepo $sourceRepo -targetRepo $targetRepo -filename $filename

    if($ret -ne $null) {
        doCommit -message $filename
        push
    }    
}

function hasCodeToBuild($targetRepo) {
    $srcPath = Join-Path -Path $targetRepo -ChildPath "src"
    $srcExists = Test-Path -Path $srcPath
    if($srcExists -eq $false) {
        # no source to update
        Write-Host "* No src folder in repo"
        return $true;
    }

    $projects = Get-ChildItem -Path $srcPath -Filter *.csproj -Recurse
    if($projects.Length -eq 0) {
        # no source to update
        Write-Host "* No C# projects in repo"
        return $false;
    }

    return $true
}

function updateFileBuildAndCommit($sourceRepo, $targetRepo, $filename) {
    $canBuild = hasCodeToBuild -targetRepo $targetRepo
    if($canBuild -eq $false) {
        return updateFileAndCommit -sourceRepo $sourceRepo -targetRepo $targetRepo -filename $filename
    }

    $ret = updateFile -sourceRepo $sourceRepo -targetRepo $targetRepo -filename $filename
    if($ret -ne $null) {
        
        if($ret -eq $true) {
            $codeOK = buildSolution -repoFolder $repoFolder
            if($codeOK -eq $true) {
                doCommit -fileName $filename
                push
            }
            else {
                $branchName = "template/ff-1429-$filename".Replace("\", "/")
                $branchOk = createBranch -name $branchName
                if($branchOk -eq $true) {
                    doCommit -fileName $filename
                    pushOrigin 
                }

                resetToMaster
            }
            
        }

        doCommit -message $filename
        return $true;
    }

    return $false;
}

function processRepo($srcRepo, $repo) {
    
    Set-Location $root
    
    Write-Host "Processing Repo: $repo"

    # Extract the folder from the repo name
    $folder = $repo.Substring($repo.LastIndexOf("/")+1)
    $folder = $folder.SubString(0, $folder.LastIndexOf("."))

    Write-Host "Folder: $folder"
    $repoFolder = Join-Path -Path $root -ChildPath $folder

    ensureSynchronised -repo $repo -repofolder $repoFolder

    $srcPath = Join-Path -Path $repoFolder -ChildPath "src"
    $srcExists = Test-Path -Path $srcPath
    if($srcExists -eq $true) {
        
        # Process files in src folder
        updatefileandcommit -sourceRepo $srcRepo -targetRepo $repoFolder -fileName "src\CodeAnalysis.ruleset"
        updatefileandcommit -sourceRepo $srcRepo -targetRepo $repoFolder -fileName "src\global.json"
    
    }


    #########################################################
    # SIMPLE OVERWRITE UPDATES
    updatefileandcommit -sourceRepo $srcRepo -targetRepo $repoFolder -fileName ".editorconfig"
    updatefileandcommit -sourceRepo $srcRepo -targetRepo $repoFolder -fileName ".gitleaks.toml"
    updatefileandcommit -sourceRepo $srcRepo -targetRepo $repoFolder -fileName ".github\pr-lint.yml"
    updatefileandcommit -sourceRepo $srcRepo -targetRepo $repoFolder -fileName ".github\CODEOWNERS"
    updatefileandcommit -sourceRepo $srcRepo -targetRepo $repoFolder -fileName ".github\PULL_REQUEST_TEMPLATE.md"
    updatefileandcommit -sourceRepo $srcRepo -targetRepo $repoFolder -fileName ".dependabot\config.yml"

    $workflows = Join-Path -Path $srcRepo -ChildPath ".github\workflows"
    $files = Get-ChildItem -Path $workflows -Filter *.yml
    ForEach($file in $files) {
	    $fileToUpdate = ".github\workflows\$file"
        updatefileandcommit -sourceRepo $srcRepo -targetRepo $repoFolder -fileName $fileToUpdate
    }
}


$repoList = loadRepoList -repos $repos


Set-Location $root
    
Write-Host "Loading template: $templateRepo"

# Extract the folder from the repo name
$templateFolder = $templateRepo.Substring($templateRepo.LastIndexOf("/")+1)
$templateFolder = $templateFolder.SubString(0, $templateFolder.LastIndexOf("."))

Write-Host "Template Folder: $templateFolder"
$templateRepoFolder = Join-Path -Path $root -ChildPath $templateFolder

ensureSynchronised -repo $templateRepo -repofolder $templateRepoFolder

Set-Location $root

ForEach($repo in $repoList) {
    processRepo -srcRepo $templateRepoFolder -repo $repo
}

Set-Location $root

