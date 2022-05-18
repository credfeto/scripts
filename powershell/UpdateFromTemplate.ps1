#########################################################################

param(
    [string] $repos = $(throw "repos.lst file containing list of repositories"),
    [string] $work = $(throw "folder where to clone repositories"),
    [string] $templateRepo = $(throw "Template repo")
)

Remove-Module *
Set-StrictMode -Version 1

$InformationPreference = "Continue"
$ErrorActionPreference = "Stop"
[bool]$preRelease = $False

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
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "GlobalJson.psm1") -Force -DisableNameChecking
}
catch
{
    Write-Error "$_"
    Throw "Error while loading supporting PowerShell Scripts: GlobalJson"
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

    [bool]$srcExists = Test-Path -Path $sourceFileName
    [bool]$trgExists = Test-Path -Path $targetFileName

    if($srcExists) {
        
        [bool]$update = $false
        if($trgExists) {
            Write-Information "--- Files exist - checking hash"
            $srcHash = Get-FileHash -Path $sourceFileName -Algorithm SHA512
            $trgHash = Get-FileHash -Path $targetFileName -Algorithm SHA512
            
            Write-Information " --- SRC: $( $srcHash.Hash )"
            Write-Information " --- TRG: $( $trgHash.Hash )"
        
            if($srcHash -eq $trgHash) {
                $update = $false
                Write-Information "--- Identical $sourceFileName to $targetFileName"
            }
            else {
                Write-Information "--- Different $sourceFileName to $targetFileName"
                $update = $true
            }
        }
        else {
            Write-Information "--- Target file does not exist - copying $sourceFileName to $targetFileName"
            $update = $true
        }
                      
        if($update) {
            Write-Information "--- Copy $sourceFileName to $targetFileName"
            Copy-Item $sourceFileName -Destination $targetFileName -Force
            return $true
        }
    }
    elseif($trgExists) {
        Write-Information "--- Delete"
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

    Write-Information "Checking $fileName"

    [string]$sourceFileName = makePath -Path $sourceRepo -ChildPath $fileName
    [string]$targetFileName = makePath -Path $targetRepo -ChildPath $fileName

    return updateOneFile -sourceFileName $sourceFileName -targetFileName $targetFileName
}

function doCommit {
param(
    [string]$fileName = $(throw "doCommit: fileName not specified"),
    [String]$repoPath = $(throw "doCommit: repoPath not specified")
)

    Write-Information "Staging $fileName in $repoPath"
    [String[]] $files = $filename.Replace("\", "/")
    Git-Commit-Named -repoPath $repoPath -message "[FF-1429] - Update $fileName to match the template repo" -files $fileName
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
                [string]$branchName = "template/ff-1429/$fileName".Replace("\", "/")
                [bool]$branchOk = Git-CreateBranch -repoPath $targetRepo -branchName $branchName
                if($branchOk) {
                    Write-Information "Create Branch $branchName"
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
        Write-Information "ERROR: $sourceFileName does not exist"
        return
    }  
    
    $files = Get-ChildItem -Path $targetRepo -Filter *.sln -Recurse
    ForEach($file in $files) {
        [string]$targetFileName = $file.FullName
        $targetFileName = $targetFileName + ".DotSettings"

        [string]$fileNameForCommit = $targetFileName.SubString($targetRepo.Length + 1)

        Write-Information "Update $targetFileName"
        [bool]$ret = updateOneFile -sourceFileName $sourceFileName -targetFileName $targetFileName
        if($ret) {
            doCommit -repoPath $targetRepo -fileName $fileNameForCommit
            Git-Push -repoPath $targetRepo
        }
    }
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
        Write-Information "Performing update on $targetFileName with text replacements"
            
        [string]$srcContent = Get-Content -Path $sourceFileName -Raw
        [string]$trgContent = Get-Content -Path $targetFileName -Raw
        
        $srcContent = $srcContent.Replace("runs-on: [self-hosted, linux]", "runs-on: ubuntu-latest")
        
        if($srcContent -ne $trgContent) {
            Set-Content -Path $targetFileName -Value $srcContent
            doCommit -repoPath $targetRepo -fileName $fileName
        }
        
    }
    else {
        Write-Information "Performing add on $targetFileName with text replacements"
        
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
    
    Write-Information "Merging ? $fileName"
    [string]$sourceFileName = makePath -Path $sourceRepo -ChildPath $fileName
    Write-Information "Source File: $sourceFileName"
    [bool]$sourceFileNameExists = Test-Path -Path $sourceFileName -PathType Leaf
    if($sourceFileNameExists -eq $false) {
        Write-Information "Non-Existent Source File: $sourceFileName"
        return
    }

    [string]$targetFileName = makePath -Path $targetRepo -ChildPath $fileName
    [string]$targetMergeFileName = makePath -Path $targetRepo -ChildPath $mergeFileName

    [bool]$targetMergeFileNameExists = Test-Path -Path $targetMergeFileName
    if($targetMergeFileNameExists -eq $true) {
        Write-Information "Found $mergeFileName"
        
        Write-Information "Source File: $sourceFileName"
        [string]$srcContent = Get-Content -Path $sourceFileName -Raw
        
        Write-Information "Merge File: $targetMergeFileName"
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
    Write-Information "Config Path: $srcPath"
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

    Write-Information "**** BUILD OK ****"
    
    Write-Information "**** DOTNET VERSION UPDATE TO $dotnetVersion"
    Git-Commit -repoPath $targetRepo -message "[FF-3881] - Updated DotNet SDK to $dotnetVersion"
    Git-Push -repoPath $targetRepo
    Git-DeleteBranch -repoPath $targetRepo -branchName $branchName
    
    Git-RemoveBranchesForPrefix -repoPath $targetRepo -branchForUpdate $branchName -branchPrefix "depends/ff-3881/update-dotnet/"
    
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

    Write-Information "**** BUILD FAILURE ****"
    [bool]$branchOk = Git-CreateBranch -repoPath $targetRepo -branchName $branchName
    if ($branchOk -eq $true) {
        Write-Information "Create Branch $branchName"
        Git-Commit -repoPath $targetRepo -message "[FF-3881] - Updated DotNet SDK to $dotnetVersion"
        Git-PushOrigin -repoPath $targetRepo -branchName $branchName
    }

    Git-ResetToMaster -repoPath $targetRepo
    
    Git-RemoveBranchesForPrefix -repoPath $targetRepo -branchForUpdate $branchName -branchPrefix "depends/ff-3881/update-dotnet/"

    # Remove any previous template updates that didn't create a version specific branch
    Git-RemoveBranchesForPrefix -repoPath $targetRepo -branchForUpdate $branchName -branchPrefix $originalBranchPrefix

}

function updateGlobalJson{
param(
    [string]$sourceRepo = $(throw "updateGlobalJson: sourceRepo not specified"), 
    [string]$targetRepo = $(throw "updateGlobalJson: targetRepo not specified"), 
    [string]$fileName = $(throw "updateGlobalJson: fileName not specified")
    )

    [string]$localFileName = convertToOsPath -path $fileName

    Write-Information "Checking $localFileName"

    [string]$sourceFileName = makePath -Path $sourceRepo -ChildPath $localFileName
    [string]$targetFileName = makePath -Path $targetRepo -ChildPath $localFileName

    [string]$originalBranchPrefix = "template/ff-3881/$fileName".Replace("\", "/")
    [string]$branchName = $originalBranchPrefix

    Write-Information "*****************"
    Write-Information "** GLOBAL.JSON **"
    Write-Information "*****************"
    $updated = GlobalJson_Update -sourceFileName $sourceFileName -targetFileName $targetFileName
    
    Write-Information "File Changed: $( $updated.Update )"
    Write-Information "Version Changed: $( $updated.UpdatingVersion )"
    Write-Information "New Version: $( $updated.NewVersion )"

    if ($updated.Update -eq $true) {    
        Write-Information "** PROCESSING GLOBAL.JSON UPDATE"
        [string]$sourceCodeFolder = makePath -Path $targetRepo -ChildPath "src"
        Write-Information "Src Folder: $sourceCodeFolder"

        if($updated.UpdatingVersion -eq $true) {
        
            [string]$dotnetVersion = $updated.NewVersion

            Write-Information "** GLOBAL.JSON VERSION UPDATED: CREATING CHANGELOG ENTRY"
            [string]$changeLogFile = makePath -Path $targetRepo -ChildPath "CHANGELOG.md"
            ChangeLog-AddEntry -fileName $changeLogFile -entryType Changed -code "FF-3881" -message "Updated DotNet SDK to $dotnetVersion"

            # Change branch name so its obvious its a dotnet update rather than just a change to the file
            [string]$branchName = "depends/ff-3881/update-dotnet/$dotnetVersion/$fileName".Replace("\", "/")

            [bool]$codeOK = DotNet-BuildSolution -srcFolder $sourceCodeFolder
            Set-Location -Path $targetRepo
            if ($codeOK -eq $true) {

                $result = commitGlobalJsonVersionUpdateToMaster -dotnetVersion $dotnetVersion -targetRepo $targetRepo -branchName $branchName -originalBranchPrefix $originalBranchPrefix

                Write-Information "Commit Result: $result"
                
                return "VERSION"
            }
            else {
                $result = commitGlobalJsonVersionUpdateToBranch -dotnetVersion $dotnetVersion -targetRepo $targetRepo -branchName $branchName -originalBranchPrefix $originalBranchPrefix
                
                Write-Information "Commit Result: $result"
                
                return "PENDING"
            }
        }
        else {
        
            Write-Information "** GLOBAL.JSON VERSION UNCHANGED BUT CONTENT CHANGED"

            [bool]$codeOK = DotNet-BuildSolution -srcFolder $sourceCodeFolder
            Set-Location -Path $targetRepo
            if ($codeOK -eq $true) {
                Write-Information "**** BUILD OK ****"
                doCommit -repoPath $targetRepo -fileName $fileName

                # Remove any previous template updates that didn't create a version specific branch
                Git-RemoveBranchesForPrefix -repoPath $targetRepo -branchForUpdate $branchName -branchPrefix $originalBranchPrefix
            }
            else {
                Write-Information "**** BUILD FAILURE ****"
                [bool]$branchOk = Git-CreateBranch -repoPath $targetRepo -branchName $branchName
                if ($branchOk -eq $true) {
                    Write-Information "Create Branch $branchName"
                    doCommit -repoPath $targetRepo -fileName $fileName
                    Git-PushOrigin -repoPath $targetRepo -branchName $branchName
                }
    
                Git-ResetToMaster -repoPath $targetRepo
            }
            
            return "CONTENT"
        }
    }
    else {
        Write-Information "No GLOBAL.JSON UPDATE"
        Write-Information "Ensuring $branchName no longer exists"
        Git-DeleteBranch -repoPath $targetRepo -branchName $branchName        
        
        return "NONE"
    }
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

function ShouldAlwaysCreatePatchRelease{
param(
    [string]$repo = $(throw "ShouldAlwaysCreatePatchRelease: repo not specified")
    )
    
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

function processRepo {
param (
    [string]$sourceRepo = $(throw "processRepo: sourceRepo not specified"), 
    [string]$repo = $(throw "processRepo: repo (target) not specified"), 
    [string]$baseFolder = $(throw "processRepo: baseFolder not specified"), 
    [string]$templateRepoHash = $(throw "processRepo: templateRepoHash not specified")
    )

    Write-Information ""
    Write-Information "***************************************************************"
    Write-Information "***************************************************************"
    Write-Information ""

    Set-Location -Path $baseFolder
    Write-Information "Base Folder: $baseFolder"
    
    Write-Information "Processing Repo: $repo"
    Write-Information "Source Repo: $sourceRepo"

    # Extract the folder from the repo name
    [string]$folder = Git-GetFolderForRepo -repo $repo

    Write-Information "Folder: $folder"
    [string]$targetRepo = Join-Path -Path $baseFolder -ChildPath $folder

    if($sourceRepo -eq $targetRepo) {
        Write-Information "Skipping updating $repo as it is the same as the template"
        Return
    }
    if([string]::IsNullOrEmpty($targetRepo)) {
        throw "Target Repo did not set up correctly"
    }
    
    Git-EnsureSynchronised -repo $repo -repoFolder $targetRepo

    Set-Location -Path $targetRepo

    [string]$lastRevision = Tracking_Get -basePath $baseFolder -repo $repo
    [string]$currentRevision = Git-Get-HeadRev -repoPath $targetRepo
    $currentRevision = "$scriptsHash/$templateRepoHash/$currentRevision"

    Write-Information "Last Revision:    $lastRevision"
    Write-Information "Current Revision: $currentRevision"

    if($lastRevision -eq $currentRevision) {
        Write-Information "Repo not changed"
        Return
    }

    Set-Location -Path $targetRepo

    #########################################################
    # CREATE ANY FOLDERS THAT ARE NEEDED
    ensureFolderExists -baseFolder $targetRepo -subFolder ".github"
    ensureFolderExists -baseFolder $targetRepo -subFolder ".github\workflows"
    ensureFolderExists -baseFolder $targetRepo -subFolder ".github\linters"

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
            [string]$versionResult = updateGlobalJson -sourceRepo $sourceRepo -targetRepo $targetRepo -fileName "src\global.json"
            Write-Information ".NET VERSION UPDATED: $versionResult"
            [bool]$dotnetVersionUpdated = $versionResult -eq "VERSION"
            Write-Information ".NET VERSION UPDATED: $dotnetVersionUpdated"
        }
        
        if($repo.Contains("funfair")) {
            Write-Information "Repo Folder contains 'funfair': $repo"
            updateFileAndCommit -sourceRepo $sourceRepo -targetRepo $targetRepo -fileName "src\FunFair.props"
            updateFileAndCommit -sourceRepo $sourceRepo -targetRepo $targetRepo -fileName "src\packageicon.png"
        }
    }

    #########################################################
    # SIMPLE OVERWRITE UPDATES
    updateFileAndCommit -sourceRepo $sourceRepo -targetRepo $targetRepo -fileName ".editorconfig"
    updateFileAndCommit -sourceRepo $sourceRepo -targetRepo $targetRepo -fileName ".gitleaks.toml"
    updateFileAndCommit -sourceRepo $sourceRepo -targetRepo $targetRepo -fileName ".gitignore"
    updateFileAndCommit -sourceRepo $sourceRepo -targetRepo $targetRepo -fileName ".gitattributes"
    updateFileAndCommit -sourceRepo $sourceRepo -targetRepo $targetRepo -fileName ".github\pr-lint.yml"
    updateFileAndCommit -sourceRepo $sourceRepo -targetRepo $targetRepo -fileName ".github\CODEOWNERS"
    updateFileAndCommit -sourceRepo $sourceRepo -targetRepo $targetRepo -fileName ".github\PULL_REQUEST_TEMPLATE.md"

    
    [string]$workflows = makePath -Path $sourceRepo -ChildPath ".github\workflows"
    Write-Information "Looking for Workflows in $workflows"
    $files = Get-ChildItem -Path $workflows -Filter *.yml -File -Attributes Normal, Hidden
    ForEach ($file in $files)
    {
        [string]$srcFileName = $file.FullName
        $srcFileName = $srcFileName.SubString($sourceRepo.Length + 1)
        Write-Information " * Found Workflow $srcFileName"

        updateWorkFlowAndCommit -sourceRepo $sourceRepo -targetRepo $targetRepo -fileName $srcFileName
    }

    [string]$targetWorkflows = makePath -Path $targetRepo -ChildPath ".github\workflows"
    $files = Get-ChildItem -Path $targetWorkflows -Filter *.yml -File -Attributes Normal, Hidden
    foreach($line in $files) {
        Write-Information "* $line"
    }
    
    $obsoleteWorkflows = @(
        "cc.yml",
        "codacy-analysis.yml",
        "dependabot-auto-merge.yml",
        "linter.yml",
        "rebase.yml",
        "sqlcheck.yml",
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

        if($match -eq $false) {
            $hasNonTemplateWorkFlows = true
            break
        }
    }

    [bool]$uncommitted = Git-HasUnCommittedChanges -repoPath $targetRepo
    If ($uncommitted -eq $true) {
        Git-Commit -repoPath $targetRepo -message "Removed old workflows"
        Git-Push -repoPath $targetRepo
    }

    [string]$linters = makePath -Path $sourceRepo -ChildPath ".github\linters"
    Write-Information "Looking for Lint config in $linters"
    $files = Get-ChildItem -Path $linters -File -Attributes Normal, Hidden
    ForEach ($file in $files) {
        [string]$srcFileName = $file.FullName
        $srcFileName = $srcFileName.SubString($sourceRepo.Length + 1)
        Write-Information " * Found Linter config $srcFileName"

        updateFileAndCommit -sourceRepo $sourceRepo -targetRepo $targetRepo -fileName $srcFileName
    }

    #########################################################
    # COMPLICATED UPDATES
    
    # Update R# DotSettings
    updateResharperSettings -sourceRepo $sourceRepo -targetRepo $targetRepo
    updateLabel -baseFolder $targetRepo

    buildDependabotConfig -sourceRepo $sourceRepo -targetRepo $targetRepo -hasNonTemplateWorkflows $hasNonTemplateWorkFlows
    removeLegacyDependabotConfig -targetRepo $targetRepo
    
    Git-ReNormalise -repoPath $targetRepo
    
    Git-ResetToMaster -repoPath $targetRepo
        
    if($dotnetVersionUpdated -eq $true) {
        Write-Information "*** SHOULD BUMP RELEASE TO NEXT PATCH RELEASE VERSION ***"
        
        if(!$repo.Contains("template"))
        {
            if (ShouldAlwaysCreatePatchRelease -repo $repo) {
                Write-Information "**** MAKE RELEASE ****"
                Write-Information "Changelog: $targetChangelogFile"
                Write-Information "Repo: $targetRepo"
                Release-Create -repo $repo -changelog $targetChangelogFile -repoPath $targetRepo
            }
            else {
                if(!$repo.Contains("server-content-package"))
                {
                    $publishable = DotNet-HasPublishableExe -srcFolder $srcPath
                    if (!$publishable -and !$repo.Contains("template"))
                    {
                        Write-Information "**** MAKE RELEASE ****"
                        Write-Information "Changelog: $targetChangelogFile"
                        Write-Information "Repo: $targetRepo"
                        Release-Create -repo $repo -changelog $targetChangelogFile -repoPath $targetRepo
                    }
                }
            }
        }        
    }

    Git-ResetToMaster -repoPath $targetRepo
    Git-ReNormalise -repoPath $targetRepo

    Write-Information "Updating Tracking for $repo to $currentRevision"
    Tracking_Set -basePath $baseFolder -repo $repo -value $currentRevision
}

function processAll {
param(
    [string[]]$repositoryList = $(throw "processAll: repositoryList not specified"), 
    [string]$templateRepositoryFolder = $(throw "processAll: templateRepositoryFolder not specified"), 
    [string]$baseFolder = $(throw "processAll: baseFolder not specified"), 
    [string]$templateRepoHash = $(throw "processAll: templateRepoHash not specified")
    )

    [int]$repoCount = $repositoryList.Count

    Write-Information "Found $repoCount repositories to process"

    ForEach($gitRepository in $repositoryList) {
        Write-Information "* $gitRepository"
    }

    ForEach($gitRepository in $repositoryList) {
        if($gitRepository.Trim() -eq "") {
            continue
        }

        processRepo -sourceRepo $templateRepoFolder -repo $gitRepository -baseFolder $baseFolder -templateRepoHash $templateRepoHash
    }
}

#########################################################################

Set-Location -Path $root
Write-Information "Root Folder: $root"

[bool]$installed = DotNetTool-Install -packageId "Credfeto.Changelog.Cmd" -preReleaseVersion $preRelease

if($installed -eq $false) {
    Write-Error ""
    Write-Error "#teamcity[buildStatus status='FAILURE' text='Failed to install Credfeto.Changelog.Cmd']"
}

[bool]$installed = DotNetTool-Install -packageId "FunFair.BuildVersion" -preReleaseVersion $preRelease

if($installed -eq $false) {
    Write-Error ""
    Write-Error "#teamcity[buildStatus status='FAILURE' text='Failed to install FunFair.BuildVersion']"
}

Write-Information ""
Write-Information "***************************************************************"
Write-Information "***************************************************************"
Write-Information ""

dotnet tool restore

Write-Information "Repository List: $repos"
[string[]] $repoList = Git-LoadRepoList -repoFile $repos

    
Write-Information ""
Write-Information "***************************************************************"
Write-Information "***************************************************************"
Write-Information ""

Write-Information "Loading template: $templateRepo"

# Extract the folder from the repo name
[string]$templateFolder = Git-GetFolderForRepo -repo $templateRepo

Write-Information "Template Folder: $templateFolder"
[string]$templateRepoFolder = Join-Path -Path $root -ChildPath $templateFolder

Git-EnsureSynchronised -repo $templateRepo -repofolder $templateRepoFolder

Set-Location -Path $templateRepoFolder

[string]$templateRepoHash = Git-Get-HeadRev -repoPath $templateRepoFolder
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
