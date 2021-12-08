#########################################################################

param(
    [string] $repos = $(throw "repos.lst file containing list of repositories"),
    [string] $work = $(throw "folder where to clone repositories"),
    [string] $templateRepo = $(throw "Template repo")
)

Remove-Module *

$InformationPreference = "Continue"
$ErrorActionPreference = "Stop"
$preRelease = $False

# Ensure $root is set to a valid path
$workDir = Resolve-Path -path $work
$root = $workDir.Path
if($root.Contains("/../")){
    Write-Error "Work folder: $work"
    Write-Error "Base folder: $root"
    throw "Invalid Base Folder: $root"
}

Write-Information $root
Write-Information "Base folder: $root"
Set-Location -Path $root


#########################################################################

# region Include required files
#
$ScriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
$ScriptDirectory = Join-Path -Path $ScriptDirectory -ChildPath "lib"
try {
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "DotNetTool.psm1") -Force -DisableNameChecking
}
catch {
    Write-Error $Error[0]
    Throw "Error while loading supporting PowerShell Scripts: DotNetTool"
}

try
{
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "GitUtils.psm1") -Force -DisableNameChecking
}
catch {
    Write-Error $Error[0]
    Throw "Error while loading supporting PowerShell Scripts: GitUtils" 
}

try
{
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "DotNetBuild.psm1") -Force -DisableNameChecking
}
catch {
    Write-Error $Error[0]
    Throw "Error while loading supporting PowerShell Scripts: DotNetBuild" 
}

try
{
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "ChangeLog.psm1") -Force -DisableNameChecking
}
catch {
    Write-Error $Error[0]
    Throw "Error while loading supporting PowerShell Scripts: ChangeLog" 
}

try
{
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "BuildVersion.psm1") -Force -DisableNameChecking
}
catch {
    Write-Error $Error[0]
    Throw "Error while loading supporting PowerShell Scripts: BuildVersion"
}

try
{
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "Tracking.psm1") -Force -DisableNameChecking
}
catch {
    Write-Error $Error[0]
    Throw "Error while loading supporting PowerShell Scripts: Tracking" 
}

try
{
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "Labeler.psm1") -Force -DisableNameChecking
}
catch
{
    Write-Error $Error[0]
    Throw "Error while loading supporting PowerShell Scripts: Labeler"
}

try
{
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "GlobalJson.psm1") -Force -DisableNameChecking
}
catch
{
    Write-Error $Error[0]
    Throw "Error while loading supporting PowerShell Scripts: GlobalJson"
}

try
{
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "Dependabot.psm1") -Force -DisableNameChecking
}
catch
{
    Write-Error $Error[0]
    Throw "Error while loading supporting PowerShell Scripts: Dependabot"
}

try
{
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "Release.psm1") -Force -DisableNameChecking
}
catch
{
    Write-Error $Error[0]
    Throw "Error while loading supporting PowerShell Scripts: Release"
}
#endregion

$scriptsHash = Git-Get-HeadRev -repoPath $ScriptDirectory

function makePath($Path, $ChildPath)
{
    $ChildPath = convertToOsPath -path $ChildPath

    return [System.IO.Path]::Combine($Path, $ChildPath)
}

function convertToOsPath($path)
{
    if ($IsLinux -eq $true)
    {
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
            Write-Information "--- Files exist - checking hash"
            $srcHash = Get-FileHash -Path $sourceFileName -Algorithm SHA512
            $trgHash = Get-FileHash -Path $targetFileName -Algorithm SHA512
        
            if($srcHash -eq $trgHash) {
                $copy = $false;
                Write-Information "--- Identical $sourceFileName to $targetFileName"
            }
        }
                      
        if($copy -eq $true) {
            Write-Information "--- Copy $sourceFileName to $targetFileName"
            Copy-Item $sourceFileName -Destination $targetFileName -Force
            return $true
        }
    }
    elseif($trgExists -eq $true) {
        Write-Information "--- Delete"
        #Remove-Item -Path $targetFileName

        #return $null
    }

    return $false;
}

function updateFile($sourceRepo, $targetRepo, $fileName) {
    $fileName = convertToOsPath -path $fileName

    Write-Information "Checking $fileName"

    $sourceFileName = makePath -Path $sourceRepo -ChildPath $fileName
    $targetFileName = makePath -Path $targetRepo -ChildPath $fileName

    return updateOneFile -sourceFileName $sourceFileName -targetFileName $targetFileName
}

function doCommit($fileName) {
    Write-Information "Staging $fileName"
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
        Write-Information "* No src folder in repo"
        return $false
    }

    $projects = Get-ChildItem -Path $srcPath -Filter *.csproj -Recurse
    if($projects.Length -eq 0) {
        # no source to update
        Write-Information "* No C# projects in repo"
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
            $codeOK = DotNet-BuildSolution -repoFolder $repoFolder
            if($codeOK) {
                doCommit -fileName $fileName
                Git-Push
            }
            else {
                $branchName = "template/ff-1429/$fileName".Replace("\", "/")
                $branchOk = Git-CreateBranch -branchName $branchName
                if($branchOk) {
                    Write-Information "Create Branch $branchName"
                    doCommit -fileName $fileName
                    Git-PushOrigin -branchName $branchName
                }

                Git-ResetToMaster
            }
            
        }

        return $true
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

        Write-Information "Update $targetFileName"
        $ret = updateOneFile -sourceFileName $sourceFileName -targetFileName $targetFileName
        if($ret -ne $null) {
            doCommit -fileName $fileNameForCommit
            Git-Push
        }
    }
}

function updateWorkFlowAndCommit($sourceRepo, $targetRepo, $fileName) {
    
    if($targetRepo.Contains("cs-template") -ne $true) {
        updateFileAndCommit -sourceRepo $srcRepo -targetRepo $trgRepo -fileName $fileName
        return
    }
    
    $sourceFileName = makePath -Path $sourceRepo -ChildPath $fileName
    $targetFileName = makePath -Path $targetRepo -ChildPath $fileName

    $targetMergeFileNameExists = Test-Path -Path $targetFileName
    if($targetMergeFileNameExists -eq $true) {
        Write-Information "Performing update on $targetFileName with text replacements"
            
        $srcContent = Get-Content -Path $sourceFileName -Raw
        $trgContent = Get-Content -Path $targetFileName -Raw
        
        $srcContent = $srcContent.Replace("runs-on: [self-hosted, linux]", "runs-on: ubuntu-latest")
        
        if($srcContent -ne $trgContent) {
            Set-Content -Path $targetFileName -Value $srcContent
            doCommit -fileName $fileName
        }
        
    }
    else {
        Write-Information "Performing add on $targetFileName with text replacements"
        
        $srcContent = Get-Content -Path $sourceFileName -Raw
        
        $srcContent = $srcContent.Replace("runs-on: [self-hosted, linux]", "runs-on: ubuntu-latest")
        
        Set-Content -Path $targetFileName -Value $srcContent
        doCommit -fileName $fileName
    }
}

function updateAndMergeFileAndCommit($srcRepo, $trgRepo, $fileName, $mergeFileName) {
    $fileName = convertToOsPath -path $fileName
    $mergeFileName = convertToOsPath -path $mergeFileName
    
    Write-Information "Merging ? $fileName"
    $sourceFileName = makePath -Path $srcRepo -ChildPath $fileName
    Write-Information "Source File: $sourceFileName"
    $sourceFileNameExists = Test-Path -Path $sourceFileName -PathType Leaf
    if($sourceFileNameExists -eq $false) {
        Write-Information "Non-Existent Source File: $sourceFileName"
        return
    }

    $targetFileName = makePath -Path $trgRepo -ChildPath $fileName
    $targetMergeFileName = makePath -Path $trgRepo -ChildPath $mergeFileName

    $targetMergeFileNameExists = Test-Path -Path $targetMergeFileName
    if($targetMergeFileNameExists -eq $true) {
        Write-Information "Found $mergeFileName"
        
        Write-Information "Source File: $sourceFileName"
        $srcContent = Get-Content -Path $sourceFileName -Raw
        
        Write-Information "Merge File: $targetMergeFileName"
        $mergeContent = Get-Content -Path $targetMergeFileName -Raw

        $trgContent = $srcContent + $mergeContent

        Set-Content -Path $targetFileName -Value $trgContent
        doCommit -fileName $fileName


    } else {
        updateFileAndCommit -sourceRepo $srcRepo -targetRepo $trgRepo -fileName $fileName
    }

}

function buildDependabotConfig($srcRepo, $trgRepo, $hasNonTemplateWorkFlows) {

    $srcPath = makePath -Path $srcRepo -ChildPath ".github"
    Write-Information "$srcPath"
    $targetFileName = makePath -Path $trgRepo -ChildPath ".github/dependabot.yml"

    $updateGitHubActions = $hasNonTemplateWorkFlows -And !$trgRepo.ToLowerInvariant().Contains("fFunfair")

    $hasSubModules = Git-HasSubModules -repoPath $trgRepo 
    Dependabot-BuildConfig -configFileName $targetFileName -repoRoot trgRepo -updateGitHubActions $updateGitHubActions -hasSubModules $hasSubModules

    doCommit -FileName ".github/dependabot.yml"
    Git-Push
}

function removeLegacyDependabotConfig($trgRepo) {
    $trgPath = makePath -Path $trgRepo -ChildPath ".github"

    $files = Get-ChildItem -Path $trgPath -filter "dependabot.config.template.*"
    foreach($file in $files)
    {
        Remove-Item -Path $file.FullName
    }

    $uncommitted = Git-HasUnCommittedChanges
    If ($uncommitted -eq $true)
    {
        Git-Commit -message "Removed old dependabot config templates"
        Git-Push
    }
}


function ensureFolderExists($baseFolder, $subFolder) {
    $fullPath = makePath -Path $baseFolder -ChildPath $subFolder
    $exists = Test-Path -Path $fullPath -PathType Container
    if($exists -eq $false) {
        New-Item -Path $baseFolder -Name $subFolder -ItemType "directory"
    }
}

function updateGlobalJson($sourceRepo, $targetRepo, $fileName) {

    $localFileName = convertToOsPath -path $fileName

    Write-Information "Checking $localFileName"

    $sourceFileName = makePath -Path $sourceRepo -ChildPath $localFileName
    $targetFileName = makePath -Path $targetRepo -ChildPath $localFileName

    $branchName = "template/ff-3881/$fileName".Replace("\", "/")

    Write-Information "*****************"
    Write-Information "** GLOBAL.JSON **"
    Write-Information "*****************"
    $updated = GlobalJson_Update -sourceFileName $sourceFileName -targetFileName $targetFileName
    
    Write-Information "File Changed: $( $updated.Update )"
    Write-Information "Version Changed: $( $updated.UpdatingVersion )"
    Write-Information "New Version: $( $updated.NewVersion )"

    if ($updated.Update -eq $true) {    
        Write-Information "** PROCESSING GLOBAL.JSON UPDATE"
        $sourceCodeFolder = makePath -Path $targetRepo -ChildPath "src"
        Write-Information "Src Folder: $sourceCodeFolder"

        if($updated.UpdatingVersion -eq $true) {
        
            Write-Information "** GLOBAL.JSON VERSION UPDATED: CREATING CHANGELOG ENTRY"
            $dotnetVersion = $updated.NewVersion
            $changeLogFile = makePath -Path $targetRepo -ChildPath "CHANGELOG.md"
            ChangeLog-AddEntry -fileName $changeLogFile -entryType Changed -code "FF-3881" -message "Updated DotNet SDK to $dotnetVersion"

            # Change branch name so its obvious its a dotnet update rather than just a change to the file
            $branchName = "depends/ff-3881/update-dotnet/$dotnetVersion/$fileName".Replace("\", "/")

            $codeOK = DotNet-BuildSolution -srcFolder $sourceCodeFolder
            Set-Location -Path $targetRepo
            if ($codeOK -eq $true) {
                Write-Information "**** BUILD OK ****"
                
                Write-Information "**** DOTNET VERSION UPDATE TO $dotnetVersion"
                Git-Commit -message "[FF-3881] - Updated DotNet SDK to $dotnetVersion"
                Git-Push
                Git-DeleteBranch -branchName $branchName
                
                return $true
            }
            else {
                Write-Information "**** BUILD FAILURE ****"
                $branchOk = Git-CreateBranch -branchName $branchName
                if ($branchOk -eq $true) {
                    Write-Information "Create Branch $branchName"
                    Git-Commit -message "[FF-3881] - Updated DotNet SDK to $dotnetVersion"
                    Git-PushOrigin -branchName $branchName
                }
    
                Git-ResetToMaster
            }
        }
        else {
        
            Write-Information "** GLOBAL.JSON VERSION UNCHANGED BUT CONTENT CHANGED"

            $codeOK = DotNet-BuildSolution -srcFolder $sourceCodeFolder
            Set-Location -Path $targetRepo
            if ($codeOK -eq $true) {
                Write-Information "**** BUILD OK ****"
                doCommit -fileName $fileName
            }
            else {
                Write-Information "**** BUILD FAILURE ****"
                $branchOk = Git-CreateBranch -branchName $branchName
                if ($branchOk -eq $true) {
                    Write-Information "Create Branch $branchName"
                    doCommit -fileName $fileName
                    Git-PushOrigin -branchName $branchName
                }
    
                Git-ResetToMaster
            }
        }
    }
    else {
        Write-Information "No GLOBAL.JSON UPDATE"
        Write-Information "Ensuring $branchName no longer exists"
        Git-DeleteBranch -branchName $branchName
    }
    
    return $false
}

function updateLabel($baseFolder) {
    $srcPath = makePath -Path $baseFolder -ChildPath "src"
    $prefix = ''
    $srcExists = Test-Path -Path $srcPath
    if($srcExists -eq $true) {
        $files = Get-ChildItem -Path $srcPath -Filter *.sln -Recurse
        if($files.Count -ne 0) {
            $prefix = $files[0].BaseName
        }
    } else {
        $srcPath = $null
    }

    $githubFolder = makePath -Path $baseFolder -ChildPath ".github"
    $mappingLabelerFile = makePath -Path $githubFolder -ChildPath "labeler.yml"
    $coloursLabelFile = makePath -Path $githubFolder -ChildPath "labels.yml"

    Labels_Update -Prefix $prefix -sourceFilesBase $srcPath -labelerFileName $mappingLabelerFile -labelsFileName $coloursLabelFile

    doCommit -FileName ".github/labeler.yml"
    doCommit -FileName ".github/labels.yml"
    Git-Push
}

function ShouldAlwaysCreatePatchRelease($repo) {
    if($repo.Contains("template")) {
        return $false
    }
        
    if($repo.Contains("credfeto")) {
        return $true
    }

    if($repo.Contains("BuildBot")) {
        return $true
    }

    if($repo.Contains("CoinBot")) {
        return $true
    }

    if($repo.Contains("funfair-server-balance-bot")) {
        return $true
    }

    return $false
}

function processRepo($srcRepo, $repo, $baseFolder, $templateRepoHash) {
    

    Write-Information ""
    Write-Information "***************************************************************"
    Write-Information "***************************************************************"
    Write-Information ""

    Set-Location -Path $baseFolder
    Write-Information "Base Folder: $baseFolder"
    
    Write-Information "Processing Repo: $repo"
    Write-Information "Source Repo: $srcRepo"

    # Extract the folder from the repo name
    $folder = Git-GetFolderForRepo -repo $repo

    Write-Information "Folder: $folder"
    $repoFolder = Join-Path -Path $baseFolder -ChildPath $folder

    if($srcRepo -eq $repoFolder) {
        Write-Information "Skipping updating $repo as it is the same as the template"
        Return
    }
    
    Git-EnsureSynchronised -repo $repo -repofolder $repoFolder

    Set-Location -Path $repoFolder

    $lastRevision = Tracking_Get -basePath $baseFolder -repo $repo
    $currentRevision = Git-Get-HeadRev
    $currentRevision = "$scriptsHash/$templateRepoHash/$currentRevision"

    Write-Information "Last Revision:    $lastRevision"
    Write-Information "Current Revision: $currentRevision"

    if( $lastRevision -eq $currentRevision) {
        Write-Information "Repo not changed"
        Return
    }

    Set-Location -Path $repoFolder

    #########################################################
    # CREATE ANY FOLDERS THAT ARE NEEDED
    ensureFolderExists -baseFolder $repoFolder -subFolder ".github"
    ensureFolderExists -baseFolder $repoFolder -subFolder ".github\workflows"
    ensureFolderExists -baseFolder $repoFolder -subFolder ".github\linters"

    ## Ensure Changelog exists
    $targetChangelogFile = makePath -Path $repoFolder -ChildPath "CHANGELOG.md"
    $targetChangeLogExists = Test-Path -Path $targetChangelogFile
    if($targetChangeLogExists -eq $false) {
        updateFileAndCommit -sourceRepo $srcRepo -targetRepo $repoFolder -fileName "CHANGELOG.md"
    }

    
    #########################################################
    # C# file updates
    $dotnetVersionUpdated = $false
    $srcPath = makePath -Path $repoFolder -ChildPath "src"
    $srcExists = Test-Path -Path $srcPath
    if($srcExists -eq $true) {
        $files = Get-ChildItem -Path $srcPath -Filter *.sln -Recurse
        if($files.Count -ne 0) {

            # Process files in src folder
            updateFileAndCommit -sourceRepo $srcRepo -targetRepo $repoFolder -fileName "src\CodeAnalysis.ruleset"
            $dotnetVersionUpdated = updateGlobalJson -sourceRepo $srcRepo -targetRepo $repoFolder -fileName "src\global.json"
            Write-Host ".NET VERSION UPDATED: $dotnetVersionUpdated"
        }
        
        if($repoFolder.Contains("funfair")) {
            updateFileAndCommit -sourceRepo $srcRepo -targetRepo $repoFolder -fileName "src\FunFair.props"
            updateFileAndCommit -sourceRepo $srcRepo -targetRepo $repoFolder -fileName "src\packageicon.png"
        }
    }

    #########################################################
    # SIMPLE OVERWRITE UPDATES
    updateFileAndCommit -sourceRepo $srcRepo -targetRepo $repoFolder -fileName ".editorconfig"
    updateFileAndCommit -sourceRepo $srcRepo -targetRepo $repoFolder -fileName ".gitleaks.toml"
    updateFileAndCommit -sourceRepo $srcRepo -targetRepo $repoFolder -fileName ".gitignore"
    updateFileAndCommit -sourceRepo $srcRepo -targetRepo $repoFolder -fileName ".gitattributes"
    updateFileAndCommit -sourceRepo $srcRepo -targetRepo $repoFolder -fileName ".github\pr-lint.yml"
    updateFileAndCommit -sourceRepo $srcRepo -targetRepo $repoFolder -fileName ".github\CODEOWNERS"
    updateFileAndCommit -sourceRepo $srcRepo -targetRepo $repoFolder -fileName ".github\PULL_REQUEST_TEMPLATE.md"

    
    $workflows = makePath -Path $srcRepo -ChildPath ".github\workflows"
    Write-Information "Looking for Workflows in $workflows"
    $files = Get-ChildItem -Path $workflows -Filter *.yml -File -Attributes Normal, Hidden
    ForEach ($file in $files)
    {
        $srcFileName = $file.FullName
        $srcFileName = $srcFileName.SubString($srcRepo.Length + 1)
        Write-Information " * Found Workflow $srcFileName"

        updateWorkFlowAndCommit -sourceRepo $srcRepo -targetRepo $repoFolder -fileName $srcFileName
    }

    $targetWorkflows = makePath -Path $trgRepo -ChildPath ".github\workflows"
    $files = Get-ChildItem -Path $targetWorkflows -Filter *.yml -File -Attributes Normal, Hidden
    Write-Information $files
    
    $obsoleteWorkflows = @(
        "cc.yml",
        "codacy-analysis.yml",
        "linter.yml",
        "sqlcheck.yml",
        "tabtospace.yml",
        "dependabot-auto-merge.yml"
    )
    ForEach ($file in $files)
    {
        ForEach ($workflow in $workflows) {
            If ($file.Name -eq $workflow) {
                Remove-Item -Path $file.FullName
                break 
            }
        }        
    }

    $templateWorkflowFiles = Get-ChildItem -Path $workflows -Filter *.yml -File -Attributes Normal, Hidden
    $targetWorkflowFiles = Get-ChildItem -Path $targetWorkflows -Filter *.yml -File -Attributes Normal, Hidden
    $hasNonTemplateWorkFlows = $False
    foreach($targetFile in $targetWorkflowFiles) {
        $targetFileName = $targetFile.Name
        $match = $False
        foreach($templateFile in $templateWorkflowFiles) {
            if($targetFileName -eq $templateFile.Name) {
                $match = $true
                break
            }
        }

        if($match -eq $false) {
            $hasNonTemplateWorkFlows = true
            break
        }
    }


    $uncommitted = Git-HasUnCommittedChanges
    If ($uncommitted -eq $true)
    {
        Git-Commit -message "Removed old workflows"
        Git-Push
    }


    $linters = makePath -Path $srcRepo -ChildPath ".github\linters"
    Write-Information "Looking for Lint config in $linters"
    $files = Get-ChildItem -Path $linters -File -Attributes Normal, Hidden
    ForEach ($file in $files)
    {
        $srcFileName = $file.FullName
        $srcFileName = $srcFileName.SubString($srcRepo.Length + 1)
        Write-Information " * Found Linter config $srcFileName"

        updateFileAndCommit -sourceRepo $srcRepo -targetRepo $repoFolder -fileName $srcFileName
    }

    #########################################################
    # COMPLICATED UPDATES
    
    # Update R# DotSettings
    updateResharperSettings -srcRepo $srcRepo -trgRepo $repoFolder
    updateLabel -baseFolder $repoFolder

    buildDependabotConfig -srcRepo $srcRepo -trgRepo $repoFolder -hasNonTemplateWorkflows $hasNonTemplateWorkFlows
    removeLegacyDependabotConfig -trgRepo $repoFolder
    
    Git-ReNormalise
    
    Git-ResetToMaster
        
    if($dotnetVersionUpdated -eq $true) {
        Write-Information "*** SHOULD BUMP RELEASE TO NEXT PATCH RELEASE VERSION ***"
        
        if(!$repo.Contains("template"))
        {
            if (ShouldAlwaysCreatePatchRelease -repo $repo) {
                Write-Information "**** MAKE RELEASE ****"
                Write-Information "Changelog: $targetChangelogFile"
                Write-Information "Repo: $repoFolder"
                Release-Create -repo $repo -changelog $targetChangelogFile -repoPath $repoFolder
            }
            else {
                if(!$repo.Contains("server-content-package"))
                {
                    $publishable = DotNet-HasPublishableExe -srcFolder $srcPath
                    if (!$publishable -and !$repo.Contains("template"))
                    {
                        Write-Information "**** MAKE RELEASE ****"
                        Write-Information "Changelog: $targetChangelogFile"
                        Write-Information "Repo: $repoFolder"
                        Release-Create -repo $repo -changelog $targetChangelogFile -repoPath $repoFolder
                    }
                }
            }
        }
        
    }

    Git-ResetToMaster
    Git-ReNormalise

    Write-Information "Updating Tracking for $repo to $currentRevision"
    Tracking_Set -basePath $baseFolder -repo $repo -value $currentRevision
}

function processAll($repositoryList, $templateRepositoryFolder, $baseFolder, $templateRepoHash) {

    $repoCount = $repositoryList.Count

    Write-Information "Found $repoCount repositories to process"

    ForEach($gitRepository in $repositoryList) {
        Write-Information "* $gitRepository"
    }

    ForEach($gitRepository in $repositoryList) {
        if($gitRepository.Trim() -eq "") {
            continue
        }

        processRepo -srcRepo $templateRepoFolder -repo $gitRepository -baseFolder $baseFolder -templateRepoHash $templateRepoHash
    }
}

#########################################################################

$installed = DotNetTool-Install -packageId "Credfeto.Changelog.Cmd" -preReleaseVersion $preRelease

if($installed -eq $false) {
    Write-Error ""
    Write-Error "#teamcity[buildStatus status='FAILURE' text='Failed to install Credfeto.Changelog.Cmd']"
}

$installed = DotNetTool-Install -packageId "FunFair.BuildVersion" -preReleaseVersion $preRelease

if($installed -eq $false) {
    Write-Error ""
    Write-Error "#teamcity[buildStatus status='FAILURE' text='Failed to install FunFair.BuildVersion']"
}



Write-Information "Repository List: $repos"
[string[]] $repoList = Git-LoadRepoList -repoFile $repos

    
Write-Information ""
Write-Information "***************************************************************"
Write-Information "***************************************************************"
Write-Information ""

Write-Information "Loading template: $templateRepo"

# Extract the folder from the repo name
$templateFolder = Git-GetFolderForRepo -repo $templateRepo

Write-Information "Template Folder: $templateFolder"
$templateRepoFolder = Join-Path -Path $root -ChildPath $templateFolder

Git-EnsureSynchronised -repo $templateRepo -repofolder $templateRepoFolder

Set-Location -Path $templateRepoFolder

$templateRepoHash = Git-Get-HeadRev
Write-Information "Template Rev Hash = $templateRepoHash"

Set-Location -Path $root

Write-Information ""
Write-Information "***************************************************************"
Write-Information "***************************************************************"
Write-Information "***************************************************************"
Write-Information "***************************************************************"
Write-Information "***************************************************************"
Write-Information "***************************************************************"
Write-Information "***************************************************************"
Write-Information ""

processAll -repositoryList $repoList -templateRepositoryFolder $templateRepoFolder -baseFolder $root -templateRepoHash $templateRepoHash

Set-Location -Path $root

Write-Information ">>>>>>>>>>>> ALL REPOS PROCESSED <<<<<<<<<<<<"
