﻿#########################################################################

param(
    [string] $repos = $(throw "repos.lst file containing list of repositories")
)

Remove-Module *

$InformationPreference = "Continue"
$ErrorActionPreference = "Stop" 
$packageIdToInstall = "JetBrains.ReSharper.GlobalTools"
$preRelease = $False
$root = Get-Location
Write-Information $root


#########################################################################

# region Include required files
#
$ScriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
$ScriptDirectory = Join-Path -Path $ScriptDirectory -ChildPath "Lib" 
Write-Information "Loading Modules from $ScriptDirectory"
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
#endregion



function runCodeCleanup($solutionFile) {

    $tempFolder = [System.IO.Path]::GetTempPath()

    $sourceFolder = Split-Path -Path $solutionFile -Parent
    $sourceFolderWithoutDrive = $sourceFolder;
    if($sourceFolder[1] -eq ":") { 
        $sourceFolderWithoutDrive = $sourceFolder.Substring(3)
    }    

    #SET SOLUTIONFILE=%~nx1
    $cachesFolder = Join-Path -Path $tempFolder -ChildPath $sourceFolderWithoutDrive
    $settingsFile = $solutionFile + ".DotSettings"

    $buildOk = DotNet-BuildSolution -srcFolder $sourceFolder
    if($buildOk -eq $true) {
        Write-Information "* Running Code Cleanup"
        Write-Information "  - Solution: $Solution"
        Write-Information "  - Cache Folder: $cachesFolder"
        Write-Information "  - Settings File: $settingsFile"

        dotnet jb cleanupcode --profile="Full Cleanup" $solutionFile --properties:Configuration=Release --caches-home:"$cachesFolder" --settings:"$settingsFile" --verbosity:WARN --no-buildin-settings --no-builtin-settings
        if(!$?) {
            Write-Information ">>>>> Code Cleanup failed"
            return $false
        }

        Write-Information "* Building after cleanup"
        return DotNet-BuildSolution -srcFolder $sourceFolder
    }

    Write-Information ">>>>> Build Failed!"
    return $false;
}


function processRepo($srcRepo, $repo) {
    
    Write-Information ""
    Write-Information "***************************************************************"
    Write-Information "***************************************************************"
    Write-Information ""

    Set-Location -Path $root
    
    Write-Information "Processing Repo: $repo"

    # Extract the folder from the repo name
    $folder = Git-GetFolderForRepo -repo $repo

    Write-Information "Folder: $folder"
    $repoFolder = Join-Path -Path $root -ChildPath $folder

    Git-EnsureSynchronised -repo $repo -repofolder $repoFolder

    Set-Location -Path $repoFolder

    #########################################################
    # C# file updates
    $srcPath = Join-Path -Path $repoFolder -ChildPath "src"
    $srcExists = Test-Path -Path $srcPath
    if($srcExists -eq $true) {
        
        $solutions = Get-ChildItem -Path $srcPath -Filter "*.sln"
        foreach($solution in $solutions) {

            $solutionFile = $solution.FullName
            $solutionName = $solution.Name
            $branchName = "cleanup/ff-2244/$solutionName"
            $branchExists = Git-DoesBranchExist -branchName $branchName
            if($branchExists -ne $true) {

                $cleaned = runCodeCleanup -solutionFile $solution.FullName
                if($cleaned -eq $true) {

                    Set-Location -Path $repoFolder

                    $hasChanges = Git-HasUnCommittedChanges
                    if($hasChanges -eq $true) {
                        Git-CreateBranch -branchName $branchName
                        Git-Commit -message "[FF-2244] - Code cleanup on $solutionName"
                        Git-PushOrigin -branchName $branchName
                    }
                }

                Git-ResetToMaster
            }
        }    
    }
}



#########################################################################


$installed = DotNetTool-Install -packageId $packageIdToInstall -preReleaseVersion $preRelease

if($installed -eq $false) {
    Write-Error ""
	Write-Error "#teamcity[buildStatus status='FAILURE' text='Failed to install $packageIdToInstall']"
}


[string[]] $repoList = Git-LoadRepoList -repoFile $repos

Write-Information ""
Write-Information "***************************************************************"
Write-Information "***************************************************************"
Write-Information ""

Set-Location -Path $root   

ForEach($repo in $repoList) {
    if($repo.Trim() -eq "") {
        continue
    }

    processRepo -srcRepo $templateRepoFolder -repo $repo
}

Set-Location -Path $root

