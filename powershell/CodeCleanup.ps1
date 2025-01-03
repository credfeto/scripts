﻿c#########################################################################

param(
    [string] $repos = $(throw "repos.lst file containing list of repositories"),
    [string] $work = $(throw "folder where to clone repositories"),
    [string] $trackingFolder = $(throw "folder where to write tracking.json file"),
    [string] $tempFolder = $(throw "folder where to write temp and caches")
)

Remove-Module *
Set-StrictMode -Version 1

$InformationPreference = "Continue"
$ErrorActionPreference = "Stop" 

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
Write-Information "Loading Modules from $ScriptDirectory"
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
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "Tracking.psm1") -Force -DisableNameChecking
}
catch {
    Write-Error "$_"
    Throw "Error while loading supporting PowerShell Scripts: Tracking" 
}

try
{
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "Resharper.psm1") -Force -DisableNameChecking
}
catch {
    Write-Error "$_"
    Throw "Error while loading supporting PowerShell Scripts: Resharper" 
}

try
{
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "ProjectCleanup.psm1") -Force -DisableNameChecking
}
catch {
    Write-Error "$_"
    Throw "Error while loading supporting PowerShell Scripts: ProjectCleanup" 
}

try
{
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "XmlDoc.psm1") -Force -DisableNameChecking
}
catch {
    Write-Error "$_"
    Throw "Error while loading supporting PowerShell Scripts: XmlDoc" 
}
#endregion

function runCodeCleanup {
param(
    [string]$solutionFile = $(throw "runCodeCleanup: solutionFile not specified"),
    [string]$workspaceCache = $(throw "runCodeCleanup: workspaceCache not specified"),
    [bool]$removeXmlDoc
    )

    $sourceFolder = Split-Path -Path $solutionFile -Parent
    $sourceFolderWithoutDrive = $sourceFolder
    if($sourceFolder[1] -eq ":") { 
        $sourceFolderWithoutDrive = $sourceFolder.Substring(3)
    }    

    $cachesFolder = Join-Path -Path $workspaceCache -ChildPath $sourceFolderWithoutDrive
    $settingsFile = $solutionFile + ".DotSettings"

    $buildOk = DotNet-BuildSolution -srcFolder $sourceFolder
    if(!$buildOk) {
        Log -message ">>>>> Build Failed! [From clean checkin]"
        return $null
    }
    
    if($removeXmlDoc) {
        $xmlDocCommentsRemoved = XmlDoc_RemoveComments -sourceFolder $sourceFolder
        $xmlDocCommentsSettingsChanged = XmlDoc_DisableDocComment -sourceFolder $sourceFolder
        if($xmlDocCommentsRemoved -Or $xmlDocCommentsSettingsChanged) {
            Log -message "* Building after removing xml doc comments"
            $buildOk = DotNet-BuildSolution -srcFolder $sourceFolder
            if(!$buildOk) {
                Log -message ">>>>> Build Failed! [From xmldoc removal]"
                return $false
            }            
        }
    }

    $changed = Resharper_ConvertSuppressionCommentToSuppressMessage -sourceFolder $sourceFolder
    if($changed) {
        Log -message "* Building after simple cleanup"
        $buildOk = DotNet-BuildSolution -srcFolder $sourceFolder
        if(!$buildOk) {
            Log -message ">>>>> Build Failed! [From simple cleanup]"
            return $false
        }
        
        # TODO: Consider commiting at this point.
    }
    
    Log -message "* Running Code Cleanup"
    Log -message "  - Solution: $Solution"
    Log -message "  - Workspace Cache Folder: $workspaceCache"
    Log -message "  - Cache Folder: $cachesFolder"
    Log -message "  - Settings File: $settingsFile"

    # Cleanup each project
    Log -message "  * Cleaning Projects"
    $projects = Get-ChildItem -Path $sourceFolder -Filter "*.csproj" -Recurse
    ForEach($project in $projects) {
        $projectFile = $project.FullName
        Log -message "    - Project $projectFile"
        
        Log -message        "    - Reorder CSPROJ"
        Project_Cleanup -projectFile $projectFile

        Log -message "* Building after simple cleanup"
        $buildOk = DotNet-BuildSolution -srcFolder $sourceFolder
        if(!$buildOk) {
            Log -message ">>>>> Build Failed! [From simple project cleanup]"
            return $false
        }
        
        # TODO: Consider commiting at this point.

        Log -message "    - JB Code Cleanup"
        DotNetTool-Require -packageId "JetBrains.ReSharper.GlobalTools"
        dotnet jb cleanupcode --profile="Full Cleanup" $projectFile --properties:Configuration=Release --properties:nodeReuse=False --caches-home:"$cachesFolder" --settings:"$settingsFile" --verbosity:INFO
         # --no-buildin-settings
        if(!$?) {
            Log -message ">>>>> Code Cleanup failed"
            throw "Code Cleanup for project failed"
            return $false
        }
        
        Log -message "* Building after simple cleanup"
        $buildOk = DotNet-BuildSolution -srcFolder $sourceFolder
        if(!$buildOk) {
            Log -message ">>>>> Build Failed! [From project cleanup]"
            return $false
        }

        # TODO: Consider commiting at this point.
    }
    
    # Cleanup the solution
    Log -message "  * Cleaning Whole Solution"
    DotNetTool-Require -packageId "JetBrains.ReSharper.GlobalTools"
    dotnet jb cleanupcode --profile="Full Cleanup" $solutionFile --properties:Configuration=Release --properties:nodeReuse=False --caches-home:"$cachesFolder" --settings:"$settingsFile" --verbosity:INFO
     
     # --no-buildin-settings
    if(!$?) {
        Log -message ">>>>> Code Cleanup failed"
        throw "Code Cleanup for solution failed"
    }

    Log -message "* Building after cleanup"
    $buildOk = DotNet-BuildSolution -srcFolder $sourceFolder
    if($buildOk) {
        return $true
    }

    Log -message ">>>>> Build Failed! [From Solution Cleanup]"
    return $false
}

function ShouldPushToBranch {
    param(
    [string]$repoPath
    )
    
#    if($repoPath.EndsWith("-server")) {
#        # Never auto cleanup servers
#        return $true
#    }
    
    return $false
}

function processRepo {
param(
    [string]$repo = $(throw "processRepo: repo not specified"),
    [string]$workspaceCache = $(throw "processRepo: workspaceCache not specified")
    )
    
    Log -message ""
    Log -message "***************************************************************"
    Log -message "***************************************************************"
    Log -message ""

    Set-Location -Path $root
    
    Log -message "Processing Repo: $repo"
    
    [bool]$removeXmlDoc = !$repo.Contains("funfair")
    [bool]$removeXmlDoc = $true

    # Extract the folder from the repo name
    $folder = Git-GetFolderForRepo -repo $repo

    Log -message "Folder: $folder"
    $repoFolder = Join-Path -Path $root -ChildPath $folder
    Log -message "Repo Folder: $repoFolder"

    Git-EnsureSynchronised -repo $repo -repoFolder $repoFolder

    Set-Location -Path $repoFolder

    $lastRevision = Tracking_Get -basePath $trackingFolder -repo $repo
    $currentRevision = Git-Get-HeadRev -repoPath $repoFolder 

    Log -message "Last Revision:    $lastRevision"
    Log -message "Current Revision: $currentRevision"

    if( $lastRevision -eq $currentRevision) {
        Log -message "Repo not changed"
    }

    $hasCleanedSuccessFully = $false
    #########################################################
    # C# file updates
    $srcPath = Join-Path -Path $repoFolder -ChildPath "src"
    $srcExists = Test-Path -Path $srcPath
    if($srcExists -eq $true) {
        
        $solutions = Get-ChildItem -Path $srcPath -Filter "*.sln" 
        foreach($solution in $solutions) {
        
            Git-ResetToMaster -repoPath $repoFolder

            $solutionFile = $solution.FullName
            $solutionName = $solution.Name
            $branchName = "cleanup/$solutionName"
            $branchExists = Git-DoesBranchExist -repoPath $repoFolder -branchName $branchName
            if($branchExists -ne $true) {

                $cleaned = runCodeCleanup -solutionFile $solution.FullName -workspaceCache $workspaceCache -removeXmlDoc $removeXmlDoc
                if($cleaned -eq $null) {
                    Git-ResetToMaster -repoPath $repoFolder
                    continue
                }

                if($cleaned) {
                    $hasCleanedSuccessFully = $true

                    Set-Location -Path $repoFolder

                    $hasChanges = Git-HasUnCommittedChanges -repoPath $repoFolder
                    if($hasChanges -eq $true) {
                        [bool]$pushToBranch = ShouldPushToBranch -repoPath $repoFolder 
                        if($pushToBranch) {                         
                            Git-CreateBranch  -repoPath $repoFolder -branchName $branchName
                            Git-Commit -repoPath $repoFolder -message "[Cleanup] - Code cleanup on $solutionName"
                            Git-PushOrigin -repoPath $repoFolder -branchName $branchName
                            
                            Git-ReNormalise -repoPath $repoFolder
                        }
                        else {
                            Git-Commit -repoPath $repoFolder -message "[Cleanup] - Code cleanup on $solutionName"
                            Git-Push -repoPath $repoFolder
                            Git-ReNormalise -repoPath $repoFolder
                        }
                    }
                }
                else {
                    $branchName = "broken/$currentRevision/cleanup/$solutionName"
                    $branchExists = Git-DoesBranchExist -repoPath $repoFolder -branchName $branchName
                    if($branchExists -ne $true) {
                        $hasChanges = Git-HasUnCommittedChanges -repoPath $repoFolder
                        if($hasChanges -eq $true) {
                            Git-CreateBranch -repoPath $repoFolder -branchName $branchName
                            Git-Commit  -repoPath $repoFolder -message "[Cleanup] - Code cleanup on $solutionName [BROKEN - NEEDS INVESTIGATION - DO NOT MERGE]"
                            Git-PushOrigin  -repoPath $repoFolder -branchName $branchName
                            
                            Git-ReNormalise -repoPath $repoFolder
                        }
                    }
                }

                Git-ResetToMaster -repoPath $repoFolder
            }
        }    
    }

    if($hasCleanedSuccessFully -eq $true) {
        Log -message "Updating Tracking for $repo to $currentRevision"
        Tracking_Set -basePath $root -repo $trackingFolder -value $currentRevision
    }

    # Always reset to master after running the cleanup
    Git-ResetToMaster -repoPath $repoFolder
}



#########################################################################

Set-Location -Path $root
Log -message "Root Folder: $root"

DotNetTool-Require -packageId "JetBrains.ReSharper.GlobalTools"
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

[string[]] $repoList = Git-LoadRepoList -repoFile $repos

Log -message ""
Log -message "***************************************************************"
Log -message "***************************************************************"
Log -message ""
Log -message "Root: $root"
Log -message "Workspace Cache: $tempFolder"

ForEach($repo in $repoList) {
    if($repo.Trim() -eq "") {
        continue
    }

    processRepo -repo $repo -workspaceCache $tempFolder
}

Set-Location -Path $root

Log -message ">>>>>>>>>>>> ALL REPOS PROCESSED <<<<<<<<<<<<"
