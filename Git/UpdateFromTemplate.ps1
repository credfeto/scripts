#########################################################################

param(
    [string] $repos = $(throw "repos.lst file containing list of repositories"),
    [string] $templateRepo = $(throw "Template repo")
)

$ErrorActionPreference = "Stop" 
#$templateRepo = "git@github.com:funfair-tech/funfair-server-template.git"
#$repos = "repos.lst"
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

function updateOneFile($sourceFileName, $targetFileName) {
    $srcExists = Test-Path -Path $sourceFileName
    $trgExists = Test-Path -Path $targetFileName

    if($srcExists -eq $true) {
        $srcHash = Get-FileHash -Path $sourceFileName -Algorithm SHA512
        $trgHash = Get-FileHash -Path $targetFileName -Algorithm SHA512
        
        if($srcHash -ne $trgHash) {
            Write-Host "--- Copy"
            Copy-Item $sourceFileName -Destination $targetFileName
            return $true
        }
    }
    elseif($trgExists -eq $true) {
        Write-Host "--- Delete"
        Remove-Item -Path $targetFileName

        return $null
    }

    return $false;
}

function updateFile($sourceRepo, $targetRepo, $fileName) {
    Write-Host "Checking $fileName"

    $sourceFileName = Join-Path -Path $sourceRepo -ChildPath $fileName
    $targetFileName = Join-Path -Path $targetRepo -ChildPath $fileName

    return updateOneFile -sourceFileName $sourceFileName -targetFileName $targetFileName
}

function doCommit($fileName) {
    commit -message "[FF-1429] - Update $fileName to match the template repo"
}

function updateFileAndCommit($sourceRepo, $targetRepo, $fileName) {

    $ret = updateFile -sourceRepo $sourceRepo -targetRepo $targetRepo -filename $fileName

    if($ret -ne $null) {
        doCommit -message $fileName
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

function updateFileBuildAndCommit($sourceRepo, $targetRepo, $fileName) {
    $canBuild = hasCodeToBuild -targetRepo $targetRepo
    if($canBuild -eq $false) {
        return updateFileAndCommit -sourceRepo $sourceRepo -targetRepo $targetRepo -filename $fileName
    }

    $ret = updateFile -sourceRepo $sourceRepo -targetRepo $targetRepo -filename $fileName
    if($ret -ne $null) {
        
        if($ret -eq $true) {
            $codeOK = buildSolution -repoFolder $repoFolder
            if($codeOK -eq $true) {
                doCommit -fileName $fileName
                push
            }
            else {
                $branchName = "template/ff-1429-$fileName".Replace("\", "/")
                $branchOk = createBranch -name $branchName
                if($branchOk -eq $true) {
                    doCommit -fileName $fileName
                    pushOrigin 
                }

                resetToMaster
            }
            
        }

        doCommit -message $fileName
        return $true;
    }

    return $false;
}

function updateResharperSettings($srcRepo, $trgRepo) {
    $sourceFileName = Join-Path -Path $srcRepo -ChildPath "src\FunFair.Template.sln.DotSettings"
    $files = Get-ChildItem -Path $repoFolder -Filter *.sln -Recurse
    ForEach($file in $files) {
        $targetFileName = $file.FullName
        $targetFileName = $targetFileName + ".DotSettings"

        Write-Host "Update $targetFileName"
        $ret = updateOneFile -sourceFileName $sourceFileName -targetFileName $targetFileName
        if($ret -ne $null) {
            doCommit -message "Resharper settings"
            push
        }
    }
}

function updateAndMergeFileAndComit($srcRepo, $trgRepo, $fileName, $mergeFileName) {
    
    $targetFileName = Join-Path -Path $trgRepo -ChildPath $fileName
    $targetMergeFileName = Join-Path -Path $trgRepo -ChildPath $mergeFileName

    $targetMergeFileNameExists = Test-Path -Path $targetMergeFileName
    if($targetMergeFileNameExists -eq $true) {
        Write-Host "Found $mergeFileName"
        $sourceFileName = Join-Path -Path $srcRepo -ChildPath $fileName
        $srcContent = Get-Content -Path $sourceFileName
        $mergeContent = Get-Content -Path $targetMergeFileName

        $trgContent = $srcRepo + "'n" + $mergeContent + "'n"

        Set-Content -Path $targetFileName -Value $trgContent
        doCommit -message $fileName


    } else {
        updateFileAndCommit -sourceRepo $srcRepo -targetRepo $trgRepo -fileName $fileName
    }

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
        updateFileAndCommit -sourceRepo $srcRepo -targetRepo $repoFolder -fileName "src\CodeAnalysis.ruleset"
        updateFileAndCommit -sourceRepo $srcRepo -targetRepo $repoFolder -fileName "src\global.json"
    
    }


    #########################################################
    # SIMPLE OVERWRITE UPDATES
    updateFileAndCommit -sourceRepo $srcRepo -targetRepo $repoFolder -fileName ".editorconfig"
    updateFileAndCommit -sourceRepo $srcRepo -targetRepo $repoFolder -fileName ".gitleaks.toml"
    updateFileAndCommit -sourceRepo $srcRepo -targetRepo $repoFolder -fileName ".github\pr-lint.yml"
    updateFileAndCommit -sourceRepo $srcRepo -targetRepo $repoFolder -fileName ".github\CODEOWNERS"
    updateFileAndCommit -sourceRepo $srcRepo -targetRepo $repoFolder -fileName ".github\PULL_REQUEST_TEMPLATE.md"
    updateFileAndCommit -sourceRepo $srcRepo -targetRepo $repoFolder -fileName ".dependabot\config.yml"

    $workflows = Join-Path -Path $srcRepo -ChildPath ".github\workflows"
    $files = Get-ChildItem -Path $workflows -Filter *.yml
    ForEach($file in $files) {
	    $fileToUpdate = ".github\workflows\$file"
        updateFileAndCommit -sourceRepo $srcRepo -targetRepo $repoFolder -fileName $fileToUpdate
    }


    #########################################################
    # COMPLICATED UPDATES
    
    # Update R# DotSettings
    updateResharperSettings -srcRepo $srcRepo -trgRepo $repoFolder


    updateAndMergeFileAndComit -srcRepo $srcRepo -trgRepo $repoFolder -fileName ".github\labeler.yml" -mergeFileName ".github\labeler.project-specific.yml"
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

