#########################################################################

param(
    [string] $repos = $(throw "repos.lst file containing list of repositories"),
    [string] $work = $(throw "folder where to clone repositories"),
    [string] $trackingFolder = $(throw "folder where to write tracking.json file"),
    [string] $templateRepo = $(throw "Template repo")
)

Remove-Module *
Set-StrictMode -Version 1

$InformationPreference = "Continue"
$ErrorActionPreference = "Stop"

# Ensure $root is set to a valid path
$workDir = Resolve-Path -path $work
[string]$root = $workDir.Path
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
[string]$ScriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
[string]$ScriptDirectory = Join-Path -Path $ScriptDirectory -ChildPath "lib"
try {
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "Log.psm1") -Force -DisableNameChecking
}
catch {
    Write-Error "$_"
    Throw "Error while loading supporting PowerShell Scripts: Log"
}
try {
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "DotNetTool.psm1") -Force -DisableNameChecking
}
catch {
    Write-Error "$_"
    Throw "Error while loading supporting PowerShell Scripts: DotNetTool"
}

try
{
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "GitUtils.psm1") -Force -DisableNameChecking
}
catch {
    Write-Error "$_"
    Throw "Error while loading supporting PowerShell Scripts: GitUtils" 
}

try
{
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "DotNetBuild.psm1") -Force -DisableNameChecking
}
catch {
    Write-Error "$_"
    Throw "Error while loading supporting PowerShell Scripts: DotNetBuild" 
}

try
{
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "ChangeLog.psm1") -Force -DisableNameChecking
}
catch {
    Write-Error "$_"
    Throw "Error while loading supporting PowerShell Scripts: ChangeLog" 
}

try
{
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "BuildVersion.psm1") -Force -DisableNameChecking
}
catch {
    Write-Error "$_"
    Throw "Error while loading supporting PowerShell Scripts: BuildVersion"
}

try
{
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "Tracking.psm1") -Force -DisableNameChecking
}
catch {
    Write-Error "$_"
    Throw "Error while loading supporting PowerShell Scripts: Tracking" 
}

try
{
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "Labeler.psm1") -Force -DisableNameChecking
}
catch
{
    Write-Error "$_"
    Throw "Error while loading supporting PowerShell Scripts: Labeler"
}

try
{
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "Dependabot.psm1") -Force -DisableNameChecking
}
catch
{
    Write-Error "$_"
    Throw "Error while loading supporting PowerShell Scripts: Dependabot"
}

try
{
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "Release.psm1") -Force -DisableNameChecking
}
catch
{
    Write-Error "$_"
    Throw "Error while loading supporting PowerShell Scripts: Release"
}
#endregion

[string]$scriptsHash = Git-Get-HeadRev -repoPath $ScriptDirectory

function makePath {
param(
    [string]$Path = $(throw "makePath: path not specified"), 
    [string]$ChildPath = $(throw "makePath: childPath not specified")
    )
    
    [string]$ChildPath = convertToOsPath -path $ChildPath

    return [System.IO.Path]::Combine($Path, $ChildPath)
}

function convertToOsPath{
param (
    [string]$path = $(throw "convertToOsPath: path not specified")
)

    if ($IsLinux -eq $true) {
        return $path.Replace("\", "/")
    }

    return $path
}


function updateOneFile {
param (
    [string]$sourceFileName = $(throw "updateOneFile: sourceFileName not specified"), 
    [string]$targetFileName = $(throw "updateOneFile: targetFileName not specified")
)
    [string]$sourceFileName = convertToOsPath -path $sourceFileName
    [string]$targetFileName = convertToOsPath -path $targetFileName

    [string]$targetFolder = $targetFileName.Substring(0, $targetFileName.LastIndexOf("/"))
    
    Log -message "--- Ensure folder exists: $targetFolder for $targetFileName"
    [bool]$targetFolderExists = Test-Path -Path $targetFolder -PathType Container
    if($targetFolderExists -eq $false) {
        Log -message "--- Creating folder: $targetFolder"
        New-Item -ItemType Directory -Path $targetFolder
    }    
    
    [bool]$srcExists = Test-Path -Path $sourceFileName
    [bool]$trgExists = Test-Path -Path $targetFileName

    if($srcExists) {
        
        [bool]$update = $false
        if($trgExists) {
            Log -message "--- Files exist - checking hash"
            $srcHash = Get-FileHash -Path $sourceFileName -Algorithm SHA512
            $trgHash = Get-FileHash -Path $targetFileName -Algorithm SHA512
            
            Log -message " --- SRC: $( $srcHash.Hash )"
            Log -message " --- TRG: $( $trgHash.Hash )"
        
            if($srcHash -eq $trgHash) {
                $update = $false
                Log -message "--- Identical $sourceFileName to $targetFileName"
            }
            else {
                Log -message "--- Different $sourceFileName to $targetFileName"
                $update = $true
            }
        }
        else {
            Log -message "--- Target file does not exist - copying $sourceFileName to $targetFileName"
            $update = $true
        }
                      
        if($update) {
            Log -message "--- Copy $sourceFileName to $targetFileName"
            Copy-Item $sourceFileName -Destination $targetFileName -Force
            return $true
        }
    }
    elseif($trgExists) {
        Log -message "--- Delete"
        #Remove-Item -Path $targetFileName

        #return $null
    }

    return $false;
}

function updateFile {
param (
    [string]$sourceRepo = $(throw "updateFile: sourceRepo not specified"), 
    [string]$targetRepo = $(throw "updateFile: targetRepo not specified"), 
    [string]$fileName = $(throw "updateFile: fileName not specified")
)
    if($sourceRepo -eq $targetRepo) {
        throw "updateFile: Source Repo and Target Repos are both set to $sourceRepo"
    }
    
    [string]$fileName = convertToOsPath -path $fileName

    Log -message "Checking $fileName"

    [string]$sourceFileName = makePath -Path $sourceRepo -ChildPath $fileName
    [string]$targetFileName = makePath -Path $targetRepo -ChildPath $fileName

    return updateOneFile -sourceFileName $sourceFileName -targetFileName $targetFileName
}

function doCommit {
param(
    [string]$fileName = $(throw "doCommit: fileName not specified"),
    [String]$repoPath = $(throw "doCommit: repoPath not specified")
)

    Log -message "Staging $fileName in $repoPath"
    [String[]] $files = $filename.Replace("\", "/")
    Git-Commit-Named -repoPath $repoPath -message "[Dependencies] - Update $fileName to match the template repo" -files $fileName
}

function updateFileAndCommit {
param (
    [string]$sourceRepo = $(throw "updateFileAndCommit: sourceRepo not specified"), 
    [string]$targetRepo = $(throw "updateFileAndCommit: targetRepo not specified"), 
    [string]$fileName = $(throw "updateFileAndCommit: filename not specified")
    )

    if($sourceRepo -eq $targetRepo) {
        throw "updateFileAndCommit: Source Repo and Target Repos are both set to $sourceRepo"
    }

    $ret = updateFile -sourceRepo $sourceRepo -targetRepo $targetRepo -filename $fileName

    if($ret -ne $null) {
        doCommit -repoPath $targetRepo -fileName $fileName
        Git-Push -repoPath $targetRepo
    }    
}


function hasCodeToBuild {
param(
    [string]$targetRepo = $(throw "hasCodeToBuild: targetRepo not specified")
    )
    
    [string]$srcPath = makePath -Path $targetRepo -ChildPath "src"
    [string]$srcExists = Test-Path -Path $srcPath
    if($srcExists -eq $false) {
        # no source to update
        Log -message "* No src folder in repo"
        return $false
    }

    $projects = Get-ChildItem -Path $srcPath -Filter *.csproj -Recurse
    if($projects.Length -eq 0) {
        # no source to update
        Log -message "* No C# projects in repo"
        return $false;
    }

    return $true
}

function updateFileBuildAndCommit {
param(
    [string]$sourceRepo = $(throw "updateFileBuildAndCommit: sourceRepo not specified"), 
    [string]$targetRepo = $(throw "updateFileBuildAndCommit: targetRepo not specified"), 
    [string]$fileName = $(throw "updateFileBuildAndCommit: targetRepo not specified")
    )
    
    if($sourceRepo -eq $targetRepo) {
        throw "updateFileBuildAndCommit: Source Repo and Target Repos are both set to $sourceRepo"
    }

    [string]$fileName = convertToOsPath -path $fileName

    [bool]$canBuild = hasCodeToBuild -targetRepo $targetRepo
    if($canBuild -eq $false) {
        return updateFileAndCommit -sourceRepo $sourceRepo -targetRepo $targetRepo -filename $fileName
    }

    [bool]$ret = updateFile -sourceRepo $sourceRepo -targetRepo $targetRepo -filename $fileName
    if($ret -ne $null) {
        
        if($ret -eq $true) {
            [bool]$codeOK = DotNet-BuildSolution -repoFolder $repoFolder
            if($codeOK) {
                doCommit -repoPath $targetRepo -fileName $fileName
                Git-Push -repoPath $targetRepo
            }
            else {
                [string]$branchName = "template/$fileName".Replace("\", "/")
                [bool]$branchOk = Git-CreateBranch -repoPath $targetRepo -branchName $branchName
                if($branchOk) {
                    Log -message "Create Branch $branchName"
                    doCommit -repoPath $targetRepo -fileName $fileName
                    Git-PushOrigin -repoPath $targetRepo -branchName $branchName
                }

                Git-ResetToMaster -repoPath $targetRepo
            }
            
        }

        return $true
    }

    return $false;
}

function updateResharperSettings {
param (
    [string]$sourceRepo = $(throw "updateResharperSettings: sourceRepo not specified"), 
    [string]$targetRepo = $(throw "updateResharperSettings: targetRepo not specified")
)
    if($sourceRepo -eq $targetRepo) {
        throw "updateResharperSettings: Source Repo and Target Repos are both set to $sourceRepo"
    }
    
    [string]$srcFolder = makePath -Path $sourceRepo -ChildPath "src"
    
    $search = Get-ChildItem -Path $srcFolder -Filter *.sln
    if(!$search) {
        # no solutions
        return;
    } 
    
    [string]$solution = $search[0].FullName
    
    [string]$sourceFileName = "$solution.DotSettings"
    $sourceTemplateExists = Test-Path -Path $sourceFileName
    if(!$sourceTemplateExists) {
        Log -message "ERROR: $sourceFileName does not exist"
        return
    }  
    
    $files = Get-ChildItem -Path $targetRepo -Filter *.sln -Recurse
    ForEach($file in $files) {
        [string]$targetFileName = $file.FullName
        $targetFileName = $targetFileName + ".DotSettings"

        [string]$fileNameForCommit = $targetFileName.SubString($targetRepo.Length + 1)

        Log -message "Update $targetFileName"
        [bool]$ret = updateOneFile -sourceFileName $sourceFileName -targetFileName $targetFileName
        if($ret) {
            doCommit -repoPath $targetRepo -fileName $fileNameForCommit
            Git-Push -repoPath $targetRepo
        }
    }
}

function updateActionAndCommit {
param(
    [string]$sourceRepo = $(throw "updateActionAndCommit: sourceRepo not specified"), 
    [string]$targetRepo = $(throw "updateActionAndCommit: targetRepo not specified"), 
    [string]$fileName = $(throw "updateActionAndCommit: filename not specified")
    )
    
    if($sourceRepo -eq $targetRepo) {
        throw "updateActionAndCommit: Source Repo and Target Repos are both set to $sourceRepo"
    }

    updateFileAndCommit -sourceRepo $sourceRepo -targetRepo $targetRepo -fileName $fileName
}

function updateWorkFlowAndCommit {
param(
    [string]$sourceRepo = $(throw "updateWorkFlowAndCommit: sourceRepo not specified"), 
    [string]$targetRepo = $(throw "updateWorkFlowAndCommit: targetRepo not specified"), 
    [string]$fileName = $(throw "updateWorkFlowAndCommit: filename not specified")
    )
    
    if($sourceRepo -eq $targetRepo) {
        throw "updateWorkFlowAndCommit: Source Repo and Target Repos are both set to $sourceRepo"
    }

    if($targetRepo.Contains("cs-template") -ne $true) {
        updateFileAndCommit -sourceRepo $sourceRepo -targetRepo $targetRepo -fileName $fileName
        return
    }
    
    [string]$sourceFileName = makePath -Path $sourceRepo -ChildPath $fileName
    [string]$targetFileName = makePath -Path $targetRepo -ChildPath $fileName

    [bool]$targetMergeFileNameExists = Test-Path -Path $targetFileName
    if($targetMergeFileNameExists -eq $true) {
        Log -message "Performing update on $targetFileName with text replacements"
            
        [string]$srcContent = Get-Content -Path $sourceFileName -Raw
        [string]$trgContent = Get-Content -Path $targetFileName -Raw
        
        $srcContent = $srcContent.Replace("runs-on: [self-hosted, linux]", "runs-on: ubuntu-latest")
        
        if($srcContent -ne $trgContent) {
            Set-Content -Path $targetFileName -Value $srcContent
            doCommit -repoPath $targetRepo -fileName $fileName
        }
        
    }
    else {
        Log -message "Performing add on $targetFileName with text replacements"
        
        $srcContent = Get-Content -Path $sourceFileName -Raw
        
        $srcContent = $srcContent.Replace("runs-on: [self-hosted, linux]", "runs-on: ubuntu-latest")
        
        Set-Content -Path $targetFileName -Value $srcContent
        doCommit -repoPath $targetRepo -fileName $fileName
    }
}

function updateAndMergeFileAndCommit {
param(
    [string]$sourceRepo = $(throw "updateAndMergeFileAndCommit: sourceRepo not specified"), 
    [string]$targetRepo = $(throw "updateAndMergeFileAndCommit: targetRepo not specified"), 
    [string]$fileName = $(throw "updateAndMergeFileAndCommit: filename not specified"), 
    [string]$mergeFileName = $(throw "updateAndMergeFileAndCommit: mergeFileName not specified")
    )
    
    $fileName = convertToOsPath -path $fileName
    [string]$mergeFileName = convertToOsPath -path $mergeFileName
    
    Log -message "Merging ? $fileName"
    [string]$sourceFileName = makePath -Path $sourceRepo -ChildPath $fileName
    Log -message "Source File: $sourceFileName"
    [bool]$sourceFileNameExists = Test-Path -Path $sourceFileName -PathType Leaf
    if($sourceFileNameExists -eq $false) {
        Log -message "Non-Existent Source File: $sourceFileName"
        return
    }

    [string]$targetFileName = makePath -Path $targetRepo -ChildPath $fileName
    [string]$targetMergeFileName = makePath -Path $targetRepo -ChildPath $mergeFileName

    [bool]$targetMergeFileNameExists = Test-Path -Path $targetMergeFileName
    if($targetMergeFileNameExists -eq $true) {
        Log -message "Found $mergeFileName"
        
        Log -message "Source File: $sourceFileName"
        [string]$srcContent = Get-Content -Path $sourceFileName -Raw
        
        Log -message "Merge File: $targetMergeFileName"
        [string]$mergeContent = Get-Content -Path $targetMergeFileName -Raw

        [string]$trgContent = $srcContent + $mergeContent

        Set-Content -Path $targetFileName -Value $trgContent
        doCommit -repoPath $repoFolder -fileName $fileName


    } else {
        updateFileAndCommit -sourceRepo $sourceRepo -targetRepo $targetRepo -fileName $fileName
    }

}

function buildDependabotConfig {
param(
    [string]$sourceRepo = $(throw "buildDependabotConfig: sourceRepo not specified"), 
    [string]$targetRepo = $(throw "buildDependabotConfig: targetRepo not specified"), 
    [bool]$hasNonTemplateWorkFlows = $(throw "buildDependabotConfig: hasNonTemplateWorkFlows not specified")
    )

    [string]$srcPath = makePath -Path $sourceRepo -ChildPath ".github"
    Log -message "Config Path: $srcPath"
    [string]$targetFileName = makePath -Path $targetRepo -ChildPath ".github/dependabot.yml"

    [bool]$updateGitHubActions = $hasNonTemplateWorkFlows
     #-And !$targetRepo.ToLowerInvariant().Contains("funfair")

    [bool]$hasSubModules = Git-HasSubModules -repoPath $targetRepo 
    Dependabot-BuildConfig -configFileName $targetFileName -repoRoot $targetRepo -updateGitHubActions $updateGitHubActions -hasSubModules $hasSubModules

    doCommit -repoPath $targetRepo -FileName ".github/dependabot.yml"
    Git-Push -repoPath $targetRepo
}

function removeLegacyDependabotConfig {
param(
    [string]$targetRepo = $(throw "removeLegacyDependabotConfig: targetRepo not specified")
    )
    
    [string]$trgPath = makePath -Path $targetRepo -ChildPath ".github"

    $files = Get-ChildItem -Path $trgPath -filter "dependabot.config.template.*"
    foreach($file in $files)
    {
        Remove-Item -Path $file.FullName
    }

    [bool]$uncommitted = Git-HasUnCommittedChanges -repoPath $targetRepo
    If ($uncommitted -eq $true)
    {
        Git-Commit -repoPath $targetRepo -message "Removed old dependabot config templates"
        Git-Push -repoPath $targetRepo
    }
}


function ensureFolderExists{
param(
    [string]$baseFolder = $(throw "ensureFolderExists: baseFolder not specified"), 
    [string]$subFolder = $(throw "ensureFolderExists: subFolder not specified")
    )
    
    [string]$fullPath = makePath -Path $baseFolder -ChildPath $subFolder
    [bool]$exists = Test-Path -Path $fullPath -PathType Container
    if($exists -eq $false) {
        New-Item -Path $baseFolder -Name $subFolder -ItemType "directory"
    }
}

function commitGlobalJsonVersionUpdateToMaster {
param (
    [string]$dotnetVersion = $(throw "commitGlobalJsonVersionUpdateToMaster: dotnetVersion not specified"),
    [string]$targetRepo = $(throw "commitGlobalJsonVersionUpdateToMaster: targetRepo not specified"),
    [string]$branchName = $(throw "commitGlobalJsonVersionUpdateToMaster: branchName not specified"),
    [string]$originalBranchPrefix = $(throw "commitGlobalJsonVersionUpdateToMaster: originalBranchPrefix not specified")
    )

    Log -message "**** BUILD OK ****"
    
    Log -message "**** DOTNET VERSION UPDATE TO $dotnetVersion"
    Git-Commit -repoPath $targetRepo -message "[SDK] - Updated DotNet SDK to $dotnetVersion"
    Git-Push -repoPath $targetRepo
    Git-DeleteBranch -repoPath $targetRepo -branchName $branchName
    
    Git-RemoveBranchesForPrefix -repoPath $targetRepo -branchForUpdate $branchName -branchPrefix "depends/update-dotnet/"
    
    # Remove any previous template updates that didn't create a version specific branch
    Git-RemoveBranchesForPrefix -repoPath $targetRepo -branchForUpdate $branchName -branchPrefix $originalBranchPrefix
}

function commitGlobalJsonVersionUpdateToBranch {
param (
    [string]$dotnetVersion = $(throw "commitGlobalJsonVersionUpdateToBranch: dotnetVersion not specified"),
    [string]$targetRepo = $(throw "commitGlobalJsonVersionUpdateToBranch: targetRepo not specified"),
    [string]$branchName = $(throw "commitGlobalJsonVersionUpdateToBranch: branchName not specified"),
    [string]$originalBranchPrefix = $(throw "commitGlobalJsonVersionUpdateToBranch: originalBranchPrefix not specified")
    )

    Log -message "**** BUILD FAILURE ****"
    [bool]$branchOk = Git-CreateBranch -repoPath $targetRepo -branchName $branchName
    if ($branchOk -eq $true) {
        Log -message "Create Branch $branchName"
        Git-Commit -repoPath $targetRepo -message "[SDK] - Updated DotNet SDK to $dotnetVersion"
        Git-PushOrigin -repoPath $targetRepo -branchName $branchName
    }

    Git-ResetToMaster -repoPath $targetRepo
    
    Git-RemoveBranchesForPrefix -repoPath $targetRepo -branchForUpdate $branchName -branchPrefix "depends/update-dotnet/"

    # Remove any previous template updates that didn't create a version specific branch
    Git-RemoveBranchesForPrefix -repoPath $targetRepo -branchForUpdate $branchName -branchPrefix $originalBranchPrefix

}

function updateLabel{
param(
    [string]$baseFolder = $(throw "updateLabel: baseFolder not specified")
    )
    
    [string]$srcPath = makePath -Path $baseFolder -ChildPath "src"
    [string]$prefix = ''
    [bool]$srcExists = Test-Path -Path $srcPath
    if($srcExists -eq $true) {
        $files = Get-ChildItem -Path $srcPath -Filter *.sln -Recurse
        if($files.Count -ne 0) {
            [string]$prefix = $files[0].BaseName
        }
    } else {
        $srcPath = $null
    }

    [string]$githubFolder = makePath -Path $baseFolder -ChildPath ".github"
    [string]$mappingLabelerFile = makePath -Path $githubFolder -ChildPath "labeler.yml"
    [string]$coloursLabelFile = makePath -Path $githubFolder -ChildPath "labels.yml"

    Labels_Update -Prefix $prefix -sourceFilesBase $srcPath -labelerFileName $mappingLabelerFile -labelsFileName $coloursLabelFile

    doCommit -repoPath $baseFolder -FileName ".github/labeler.yml"
    doCommit -repoPath $baseFolder -FileName ".github/labels.yml"
    Git-Push -repoPath $baseFolder
}

function processRepo {
param (
    [string]$sourceRepo = $(throw "processRepo: sourceRepo not specified"), 
    [string]$repo = $(throw "processRepo: repo (target) not specified"), 
    [string]$baseFolder = $(throw "processRepo: baseFolder not specified"), 
    [string]$templateRepoHash = $(throw "processRepo: templateRepoHash not specified")
    )

    Log -message ""
    Log -message "***************************************************************"
    Log -message "***************************************************************"
    Log -message ""

    Set-Location -Path $baseFolder
    Log -message "Base Folder: $baseFolder"
    
    Log -message "Processing Repo: $repo"
    Log -message "Source Repo: $sourceRepo"

    # Extract the folder from the repo name
    [string]$folder = Git-GetFolderForRepo -repo $repo

    Log -message "Folder: $folder"
    [string]$targetRepo = Join-Path -Path $baseFolder -ChildPath $folder

    if($sourceRepo -eq $targetRepo) {
        Log -message "Skipping updating $repo as it is the same as the template"
        Return
    }
    if([string]::IsNullOrEmpty($targetRepo)) {
        throw "Target Repo did not set up correctly"
    }
    
    Git-EnsureSynchronised -repo $repo -repoFolder $targetRepo

    Set-Location -Path $targetRepo

    [string]$lastRevision = Tracking_Get -basePath $trackingFolder -repo $repo
    [string]$currentRevision = Git-Get-HeadRev -repoPath $targetRepo
    $currentRevision = "$scriptsHash/$templateRepoHash/$currentRevision"

    Log -message "Last Revision:    $lastRevision"
    Log -message "Current Revision: $currentRevision"

    if($lastRevision -eq $currentRevision) {
        Log -message "Repo not changed"
        Return
    }

    Set-Location -Path $targetRepo

    #########################################################
    # CREATE ANY FOLDERS THAT ARE NEEDED
    ensureFolderExists -baseFolder $targetRepo -subFolder ".github"
    ensureFolderExists -baseFolder $targetRepo -subFolder ".github\workflows"
    ensureFolderExists -baseFolder $targetRepo -subFolder ".github\actions"
    ensureFolderExists -baseFolder $targetRepo -subFolder ".github\linters"
    ensureFolderExists -baseFolder $targetRepo -subFolder ".github\ISSUE_TEMPLATE"

    ## Ensure Changelog exists
    [string]$targetChangelogFile = makePath -Path $targetRepo -ChildPath "CHANGELOG.md"
    [bool]$targetChangeLogExists = Test-Path -Path $targetChangelogFile
    if($targetChangeLogExists -eq $false) {
        updateFileAndCommit -sourceRepo $sourceRepo -targetRepo $targetRepo -fileName "CHANGELOG.md"
    }

    
    #########################################################
    # C# file updates
    [bool]$dotnetVersionUpdated = $false
    [string]$srcPath = makePath -Path $targetRepo -ChildPath "src"
    [bool]$srcExists = Test-Path -Path $srcPath
    if($srcExists -eq $true) {
        $files = Get-ChildItem -Path $srcPath -Filter *.sln -Recurse
        if($files.Count -ne 0) {

            # Process files in src folder
            updateFileAndCommit -sourceRepo $sourceRepo -targetRepo $targetRepo -fileName "src\CodeAnalysis.ruleset"
        }
        
        if($repo.Contains("funfair")) {
            Log -message "Repo Folder contains 'funfair': $repo"
            updateFileAndCommit -sourceRepo $sourceRepo -targetRepo $targetRepo -fileName "src\FunFair.props"
            updateFileAndCommit -sourceRepo $sourceRepo -targetRepo $targetRepo -fileName "src\packageicon.png"
        }
        
        updateFileAndCommit -sourceRepo $sourceRepo -targetRepo $targetRepo -fileName "src\Directory.Build.props"
    }

#     #########################################################
#     # SIMPLE OVERWRITE UPDATES
#     updateFileAndCommit -sourceRepo $sourceRepo -targetRepo $targetRepo -fileName ".editorconfig"
#     updateFileAndCommit -sourceRepo $sourceRepo -targetRepo $targetRepo -fileName ".gitleaks.toml"
#     updateFileAndCommit -sourceRepo $sourceRepo -targetRepo $targetRepo -fileName ".gitignore"
#     updateFileAndCommit -sourceRepo $sourceRepo -targetRepo $targetRepo -fileName ".gitattributes"
#     updateFileAndCommit -sourceRepo $sourceRepo -targetRepo $targetRepo -fileName ".tsqllintrc"
#     updateFileAndCommit -sourceRepo $sourceRepo -targetRepo $targetRepo -fileName ".github\pr-lint.yml"
#     updateFileAndCommit -sourceRepo $sourceRepo -targetRepo $targetRepo -fileName ".github\CODEOWNERS"
#     updateFileAndCommit -sourceRepo $sourceRepo -targetRepo $targetRepo -fileName ".github\PULL_REQUEST_TEMPLATE.md"
#     updateFileAndCommit -sourceRepo $sourceRepo -targetRepo $targetRepo -fileName "CONTRIBUTING.md"
#     updateFileAndCommit -sourceRepo $sourceRepo -targetRepo $targetRepo -fileName "SECURITY.md"
# 
#     
#     [string]$issueTemplates = makePath -Path $sourceRepo -ChildPath ".github\ISSUE_TEMPLATE"
#     Log -message "Looking for issue templates in $issueTemplates"
#     $files = Get-ChildItem -Path $issueTemplates -Filter *.md -File -Attributes Normal, Hidden -Recurse
#     ForEach ($file in $files)
#     {
#         [string]$srcFileName = $file.FullName
#         $srcFileName = $srcFileName.SubString($sourceRepo.Length + 1)
#         Log -message " * Found issue template: $srcFileName"
# 
#         updateActionAndCommit -sourceRepo $sourceRepo -targetRepo $targetRepo -fileName $srcFileName
#     }
#         
#     [string]$actions = makePath -Path $sourceRepo -ChildPath ".github\actions"
#     Log -message "Looking for action in $actions"
#     $files = Get-ChildItem -Path $actions -Filter *.yml -File -Attributes Normal, Hidden -Recurse
#     ForEach ($file in $files)
#     {
#         [string]$srcFileName = $file.FullName
#         $srcFileName = $srcFileName.SubString($sourceRepo.Length + 1)
#         Log -message " * Found action $srcFileName"
# 
#         updateActionAndCommit -sourceRepo $sourceRepo -targetRepo $targetRepo -fileName $srcFileName
#     }

    [string]$workflows = makePath -Path $sourceRepo -ChildPath ".github\workflows"
    Log -message "Looking for Workflows in $workflows"
    $files = Get-ChildItem -Path $workflows -Filter *.yml -File -Attributes Normal, Hidden
#     ForEach ($file in $files)
#     {
#         [string]$srcFileName = $file.FullName
#         $srcFileName = $srcFileName.SubString($sourceRepo.Length + 1)
#         Log -message " * Found Workflow $srcFileName"
# 
#         updateWorkFlowAndCommit -sourceRepo $sourceRepo -targetRepo $targetRepo -fileName $srcFileName
#     }

    [string]$targetWorkflows = makePath -Path $targetRepo -ChildPath ".github\workflows"
    $files = Get-ChildItem -Path $targetWorkflows -Filter *.yml -File -Attributes Normal, Hidden
    foreach($line in $files) {
        Log -message "* $line"
    }
    
    $obsoleteWorkflows = @(
        "cc.yml",
        "check-case.yml",
        "codacy-analysis.yml",
        "codeql-analysis-csharp.yml",
        "codeql-analysis-javascript.yml"
        "codeql-analysis-python.yml",
        "dependabot-auto-merge.yml",
        "dependabot-rebase.yml",
        "linter.yml",
        "rebase.yml",
        "sqlcheck.yml",
        "stale.yml",
        "tabtospace.yml"                
    )
    ForEach ($file in $files) {
        ForEach ($workflow in $obsoleteWorkflows) {
            If ($file.Name -eq $workflow) {
                Remove-Item -Path $file.FullName
                break 
            }
        }        
    }

    $templateWorkflowFiles = Get-ChildItem -Path $workflows -Filter *.yml -File -Attributes Normal, Hidden
    $targetWorkflowFiles = Get-ChildItem -Path $targetWorkflows -Filter *.yml -File -Attributes Normal, Hidden
    [bool]$hasNonTemplateWorkFlows = $False
    foreach($targetFile in $targetWorkflowFiles) {
        [string]$targetFileName = $targetFile.Name
        [bool]$match = $False
        foreach($templateFile in $templateWorkflowFiles) {
            if($targetFileName -eq $templateFile.Name) {
                $match = $true
                break
            }
        }

        if(!$match) {
            Log -message "Non-Template Workflow found: $targetFileName"
            $hasNonTemplateWorkFlows = $true
            break
        }
    }

    [bool]$uncommitted = Git-HasUnCommittedChanges -repoPath $targetRepo
    If ($uncommitted -eq $true) {
        Git-Commit -repoPath $targetRepo -message "Removed old workflows"
        Git-Push -repoPath $targetRepo
    }

#     [string]$linters = makePath -Path $sourceRepo -ChildPath ".github\linters"
#     Log -message "Looking for Lint config in $linters"
#     $files = Get-ChildItem -Path $linters -File -Attributes Normal, Hidden
#     ForEach ($file in $files) {
#         [string]$srcFileName = $file.FullName
#         $srcFileName = $srcFileName.SubString($sourceRepo.Length + 1)
#         Log -message " * Found Linter config $srcFileName"
# 
#         updateFileAndCommit -sourceRepo $sourceRepo -targetRepo $targetRepo -fileName $srcFileName
#     }

    #########################################################
    # COMPLICATED UPDATES
    
    # Update R# DotSettings
    # updateResharperSettings -sourceRepo $sourceRepo -targetRepo $targetRepo
    updateLabel -baseFolder $targetRepo

    buildDependabotConfig -sourceRepo $sourceRepo -targetRepo $targetRepo -hasNonTemplateWorkflows $hasNonTemplateWorkFlows
    removeLegacyDependabotConfig -targetRepo $targetRepo
    
    Git-ReNormalise -repoPath $targetRepo
    
    Git-ResetToMaster -repoPath $targetRepo
        
    if($dotnetVersionUpdated -eq $true) {
        Log -message "*** SHOULD BUMP RELEASE TO NEXT PATCH RELEASE VERSION ***"
        
        if(!$repo.Contains("template"))
        {
            Release-TryCreateNextPatch -repo $repo -repoPath $targetRepo -changelog $targetChangelogFile 
        }        
    }

    Git-ResetToMaster -repoPath $targetRepo
    Git-ReNormalise -repoPath $targetRepo

    Log -message "Updating Tracking for $repo to $currentRevision"
    Tracking_Set -basePath $trackingFolder -repo $repo -value $currentRevision
}

function processAll {
param(
    [string[]]$repositoryList = $(throw "processAll: repositoryList not specified"), 
    [string]$templateRepositoryFolder = $(throw "processAll: templateRepositoryFolder not specified"), 
    [string]$baseFolder = $(throw "processAll: baseFolder not specified"), 
    [string]$templateRepoHash = $(throw "processAll: templateRepoHash not specified")
    )

    [int]$repoCount = $repositoryList.Count

    Log -message "Found $repoCount repositories to process"

    ForEach($gitRepository in $repositoryList) {
        Log -message "* $gitRepository"
    }

    ForEach($gitRepository in $repositoryList) {
        if($gitRepository.Trim() -eq "") {
            continue
        }

        processRepo -sourceRepo $templateRepoFolder -repo $gitRepository -baseFolder $baseFolder -templateRepoHash $templateRepoHash
    }
}

#########################################################################

Log -message "Repos: $repos"
Log -message "Root Folder: $root"
Log -message "Work Folder: $work"
Log -message "Tracking: $trackingFolder"
Log -message "Template: $templateRepo"

Set-Location -Path $root


DotNetTool-Require -packageId "Credfeto.Changelog.Cmd"
DotNetTool-Require -packageId "FunFair.BuildVersion"
DotNetTool-Require -packageId "FunFair.BuildCheck"
dotnet new install MSBuild.Sdk.SqlProj.Templates

Log -message ""
Log -message "***************************************************************"
Log -message "***************************************************************"
Log -message ""

dotnet tool list

Log -message ""
Log -message "***************************************************************"
Log -message "***************************************************************"
Log -message ""


Log -message "Repository List: $repos"
[string[]] $repoList = Git-LoadRepoList -repoFile $repos

    
Log -message ""
Log -message "***************************************************************"
Log -message "***************************************************************"
Log -message ""

Log -message "Loading template: $templateRepo"

# Extract the folder from the repo name
[string]$templateFolder = Git-GetFolderForRepo -repo $templateRepo

Log -message "Template Folder: $templateFolder"
[string]$templateRepoFolder = Join-Path -Path $root -ChildPath $templateFolder

Git-EnsureSynchronised -repo $templateRepo -repofolder $templateRepoFolder

Set-Location -Path $templateRepoFolder

[string]$templateRepoHash = Git-Get-HeadRev -repoPath $templateRepoFolder
Log -message "Template Rev Hash = $templateRepoHash"

Set-Location -Path $root

Log -message ""
Log -message "***************************************************************"
Log -message "***************************************************************"
Log -message "***************************************************************"
Log -message "***************************************************************"
Log -message "***************************************************************"
Log -message "***************************************************************"
Log -message "***************************************************************"
Log -message ""


processAll -repositoryList $repoList -templateRepositoryFolder $templateRepoFolder -baseFolder $root -templateRepoHash $templateRepoHash

Set-Location -Path $root

Log -message ">>>>>>>>>>>> ALL REPOS PROCESSED <<<<<<<<<<<<"
