#########################################################################

param(
    [string] $repos = $(throw "repos.lst file containing list of repositories"),
    [string] $templateRepo = $(throw "Template repo")
)

$ErrorActionPreference = "Stop" 
$root = (Get-Location).Path
Write-Output $root


#########################################################################

# region Include required files
#
$ScriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
$ScriptDirectory = Join-Path -Path $ScriptDirectory -ChildPath "Lib" 
try {
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "GitUtils.psm1") -Force -DisableNameChecking
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "DotNetBuild.psm1") -Force -DisableNameChecking
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "ChangeLog.psm1") -Force -DisableNameChecking
}
catch {
    Throw "Error while loading supporting PowerShell Scripts" 
}
#endregion

function makePath($Path, $ChildPath) {
    $ChildPath = convertToOsPath -path $ChildPath

    return [System.IO.Path]::Combine($Path,$ChildPath)
}

function convertToOsPath($path) {
    if($IsLinux -eq $true) {
        return $path.Replace("\", "/")
    }

    return $path
}


function updateOneFile($sourceFileName, $targetFileName) {
    $sourceFileName = convertToOsPath -path $sourceFileName
    $targetFileName = convertToOsPath -path $targetFileName

    $srcExists = Test-Path -Path $sourceFileName
    $trgExists = Test-Path -Path $targetFileName

    if($srcExists -eq $true) {
        
        $copy = $true
        if($trgExists -eq $true) {
            Write-Output "--- Files exist - checking hash"
            $srcHash = Get-FileHash -Path $sourceFileName -Algorithm SHA512
            $trgHash = Get-FileHash -Path $targetFileName -Algorithm SHA512
        
            if($srcHash -eq $trgHash) {
                $copy = $false;
                Write-Output "--- Identical $sourceFileName to $targetFileName"
            }
        }
                      
        if($copy -eq $true) {
            Write-Output "--- Copy $sourceFileName to $targetFileName"
            Copy-Item $sourceFileName -Destination $targetFileName -Force
            return $true
        }
    }
    elseif($trgExists -eq $true) {
        Write-Output "--- Delete"
        #Remove-Item -Path $targetFileName

        #return $null
    }

    return $false;
}

function updateFile($sourceRepo, $targetRepo, $fileName) {
    $fileName = convertToOsPath -path $fileName

    Write-Output "Checking $fileName"

    $sourceFileName = makePath -Path $sourceRepo -ChildPath $fileName
    $targetFileName = makePath -Path $targetRepo -ChildPath $fileName

    return updateOneFile -sourceFileName $sourceFileName -targetFileName $targetFileName
}

function doCommit($fileName) {
    Write-Output "Staging $fileName"
    [String[]] $files = $filename.Replace("\", "/")
    Git-Commit-Named -message "[FF-1429] - Update $fileName to match the template repo" -files $fileName
}

function updateFileAndCommit($sourceRepo, $targetRepo, $fileName) {

    $ret = updateFile -sourceRepo $sourceRepo -targetRepo $targetRepo -filename $fileName

    if($ret -ne $null) {
        doCommit -fileName $fileName
        Git-Push
    }    
}


function hasCodeToBuild($targetRepo) {
    $srcPath = makePath -Path $targetRepo -ChildPath "src"
    $srcExists = Test-Path -Path $srcPath
    if($srcExists -eq $false) {
        # no source to update
        Write-Output "* No src folder in repo"
        return $true;
    }

    $projects = Get-ChildItem -Path $srcPath -Filter *.csproj -Recurse
    if($projects.Length -eq 0) {
        # no source to update
        Write-Output "* No C# projects in repo"
        return $false;
    }

    return $true
}

function updateFileBuildAndCommit($sourceRepo, $targetRepo, $fileName) {
    $fileName = convertToOsPath -path $fileName

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
                Git-Push
            }
            else {
                $branchName = "template/ff-1429/$fileName".Replace("\", "/")
                $branchOk = createBranch -name $branchName
                if($branchOk -eq $true) {
                    Write-Output "Create Branch $branchName"
                    doCommit -fileName $fileName
                    Git-PushOrigin -branchName $branchName
                }

                Git-ResetToMaster
            }
            
        }

        return $true;
    }

    return $false;
}

function updateResharperSettings($srcRepo, $trgRepo) {
    $sourceTemplateFile = convertToOsPath -path "src\FunFair.Template.sln.DotSettings"

    $sourceFileName = makePath -Path $srcRepo -ChildPath $sourceTemplateFile
    $files = Get-ChildItem -Path $repoFolder -Filter *.sln -Recurse
    ForEach($file in $files) {
        $targetFileName = $file.FullName
        $targetFileName = $targetFileName + ".DotSettings"

        $fileNameForCommit = $targetFileName.SubString($trgRepo.Length + 1)

        Write-Output "Update $targetFileName"
        $ret = updateOneFile -sourceFileName $sourceFileName -targetFileName $targetFileName
        if($ret -ne $null) {
            doCommit -fileName $fileNameForCommit
            Git-Push
        }
    }
}

function updateAndMergeFileAndComit($srcRepo, $trgRepo, $fileName, $mergeFileName) {
    $fileName = convertToOsPath -path $fileName
    $mergeFileName = convertToOsPath -path $mergeFileName
    
    Write-Output "Merging ? $fileName"
    $sourceFileName = makePath -Path $srcRepo -ChildPath $fileName
    Write-Output "Source File: $sourceFileName"
    $sourceFileNameExists = Test-Path -Path $sourceFileName -PathType Leaf
    if($sourceFileNameExists -eq $false) {
        Write-Output "Non-Existent Source File: $sourceFileName"
        return
    }

    $targetFileName = makePath -Path $trgRepo -ChildPath $fileName
    $targetMergeFileName = makePath -Path $trgRepo -ChildPath $mergeFileName

    $targetMergeFileNameExists = Test-Path -Path $targetMergeFileName
    if($targetMergeFileNameExists -eq $true) {
        Write-Output "Found $mergeFileName"
        
        Write-Output "Source File: $sourceFileName"
        $srcContent = Get-Content -Path $sourceFileName -Raw
        
        Write-Output "Merge File: $targetMergeFileName"
        $mergeContent = Get-Content -Path $targetMergeFileName -Raw

        $trgContent = $srcContent + $mergeContent

        Set-Content -Path $targetFileName -Value $trgContent
        doCommit -fileName $fileName


    } else {
        updateFileAndCommit -sourceRepo $srcRepo -targetRepo $trgRepo -fileName $fileName
    }

}

function buildDependabotConfig($srcRepo, $trgRepo) {

    $srcPath = makePath -Path $srcRepo -ChildPath ".dependabot"
    Write-Output "$srcPath"
    $targetFileName = makePath -Path $trgRepo -ChildPath ".dependabot\config.yml"

    Write-Output "Building Dependabot Config:"
    $trgContent = "version: 1
update_configs:
"

    $templateFile = makePath -Path $srcPath -ChildPath 'config.template.dotnet'
    $templateFileExists = Test-Path -Path $templateFile
    if($templateFileExists -eq $true) {        
        $files = Get-ChildItem -Path $trgRepo -Filter *.csproj -Recurse
        if($files -ne $null) {
            Write-Output " --> Addning .NET"
            $templateContent = Get-Content -Path $templateFile -Raw
            $trgContent = $trgContent + $templateContent
        }
    }

    $templateFile = makePath -Path $srcPath -ChildPath 'config.template.javascript'
    $templateFileExists = Test-Path -Path $templateFile
    if($templateFileExists -eq $true) {
        $files = Get-ChildItem -Path $trgRepo -Filter 'package.json' -Recurse
        if($files -ne $null) {
            Write-Output " --> Addning Javascript"
            $templateContent = Get-Content -Path $templateFile -Raw
            $trgContent = $trgContent + $templateContent
        }
    }

    $templateFile = makePath -Path $srcPath -ChildPath 'config.template.docker'
    $templateFileExists = Test-Path -Path $templateFile
    if($templateFileExists -eq $true) {
        $files = Get-ChildItem -Path $trgRepo -Filter 'Dockerfile' -Recurse
        if($files -ne $null) {
            Write-Output " --> Adding Docker"
            $templateContent = Get-Content -Path $templateFile -Raw
            $trgContent = $trgContent + $templateContent
        }
    }

    $templateFile = makePath -Path $srcPath -ChildPath 'config.template.github_actions'
    $templateFileExists = Test-Path -Path $templateFile
    if($templateFileExists -eq $true) {
        $actionsTargetPath = makePath -Path $trgRepo -ChildPath ".github"
        $files = Get-ChildItem -Path $actionsTargetPath -Filter *.yml -Recurse
        if($files -ne $null) {
            Write-Output " --> Adding Github Actions"
            $templateContent = Get-Content -Path $templateFile -Raw
            $trgContent = $trgContent +  $templateContent
        }
    }

    Write-Output " --> Done"
    Set-Content -Path $targetFileName -Value $trgContent

    doCommit -FileName ".dependabot/config.yml"
    Git-Push
}


function ensureFolderExists($baseFolder, $subFolder) {
    $fullPath = makePath -Path $baseFolder -ChildPath $subFolder
    $exists = Test-Path -Path $fullPath -PathType Container
    if($exists -eq $false) {
        New-Item -Path $baseFolder -Name $subFolder -ItemType "directory"
    }
}

function processRepo($srcRepo, $repo) {
    
    Set-Location -Path $root
    
    Write-Output "Processing Repo: $repo"

    # Extract the folder from the repo name
    $folder = $repo.Substring($repo.LastIndexOf("/")+1)
    $folder = $folder.SubString(0, $folder.LastIndexOf("."))

    Write-Output "Folder: $folder"
    $repoFolder = Join-Path -Path $root -ChildPath $folder

    
    Git-EnsureSynchronised -repo $repo -repofolder $repoFolder

    Set-Location -Path $repoFolder

    #########################################################
    # CREATE ANY FOLDERS THAT ARE NEEDED
    ensureFolderExists -baseFolder $repoFolder -subFolder "src"
    ensureFolderExists -baseFolder $repoFolder -subFolder ".github"
    ensureFolderExists -baseFolder $repoFolder -subFolder ".github\workflows"
    ensureFolderExists -baseFolder $repoFolder -subFolder ".dependabot"


    #########################################################
    # C# file updates
    $srcPath = makePath -Path $repoFolder -ChildPath "src"
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

    
    $workflows = makePath -Path $srcRepo -ChildPath ".github\workflows"
    $files = Get-ChildItem -Path $workflows -Filter *.yml
    ForEach($file in $files) {
        $srcFileName = $file.FullName
        $srcFileName = $srcFileName.SubString($srcRepo.Length + 1)

	    $fileToUpdate = $srcFileName
        updateFileAndCommit -sourceRepo $srcRepo -targetRepo $repoFolder -fileName $fileToUpdate
    }


    #########################################################
    # COMPLICATED UPDATES
    
    # Update R# DotSettings
    updateResharperSettings -srcRepo $srcRepo -trgRepo $repoFolder


    updateAndMergeFileAndComit -srcRepo $srcRepo -trgRepo $repoFolder -fileName ".github\labeler.yml" -mergeFileName ".github\labeler.project-specific.yml"

    buildDependabotConfig -srcRepo $srcRepo -trgRepo $repoFolder
}


Write-Output "Repository List: $repos"
$repoList = Git-LoadRepoList -repoFile $repos

Write-Output "Base folder: $root"
Set-Location -Path $root
    
Write-Output "Loading template: $templateRepo"

# Extract the folder from the repo name
$templateFolder = $templateRepo.Substring($templateRepo.LastIndexOf("/")+1)
$templateFolder = $templateFolder.SubString(0, $templateFolder.LastIndexOf("."))

Write-Output "Template Folder: $templateFolder"
$templateRepoFolder = Join-Path -Path $root -ChildPath $templateFolder

Git-EnsureSynchronised -repo $templateRepo -repofolder $templateRepoFolder

Set-Location -Path $root

ForEach($repo in $repoList) {
    if($repo.Trim() -eq "") {
        continue
    }

    processRepo -srcRepo $templateRepoFolder -repo $repo
}

Set-Location -Path $root

