#########################################################################

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
$ScriptDirectory = Join-Path -Path $ScriptDirectory -ChildPath "lib" 
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
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "Resharper.psm1") -Force -DisableNameChecking
}
catch {
    Write-Error $Error[0]
    Throw "Error while loading supporting PowerShell Scripts: Resharper" 
}

try
{
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "ProjectCleanup.psm1") -Force -DisableNameChecking
}
catch {
    Write-Error $Error[0]
    Throw "Error while loading supporting PowerShell Scripts: ProjectCleanup" 
}
#endregion

function runCodeCleanup($solutionFile) {

    $tempFolder = [System.IO.Path]::GetTempPath()

    $sourceFolder = Split-Path -Path $solutionFile -Parent
    $sourceFolderWithoutDrive = $sourceFolder
    if($sourceFolder[1] -eq ":") { 
        $sourceFolderWithoutDrive = $sourceFolder.Substring(3)
    }    

    $cachesFolder = Join-Path -Path $tempFolder -ChildPath $sourceFolderWithoutDrive
    $settingsFile = $solutionFile + ".DotSettings"

    $buildOk = DotNet-BuildSolution -srcFolder $sourceFolder
    if(!$buildOk) {
        Write-Information ">>>>> Build Failed! [From clean checkin]"
        return $null
    }

    $changed = Resharper_ConvertSuppressionCommentToSuppressMessage -sourceFolder $sourceFolder
    if($changed) {
        Write-Information "* Building after simple cleanuo"
        $buildOk = DotNet-BuildSolution -srcFolder $sourceFolder
        if(!$buildOk) {
            Write-Information ">>>>> Build Failed! [From simple cleanup]"
            return $false
        }
    }

    Write-Information "* Running Code Cleanup"
    Write-Information "  - Solution: $Solution"
    Write-Information "  - Cache Folder: $cachesFolder"
    Write-Information "  - Settings File: $settingsFile"

    # Cleanup each project
    $projects = Get-ChildItem -Path $sourceFolder -Filter "*.csproj" -Recurse
    ForEach($project in $projects) {
        $projectFile = $project.FullName
        Write-Information "  - Project $projectFile"
        
        Write-Host "     - Reorder CSPROJ"
        Project_Cleanup -projectFile $projectFile

        Write-Host "     - JB Code Cleanup"
        dotnet jb cleanupcode --profile="Full Cleanup" $projectFile --properties:Configuration=Release --properties:nodeReuse=False --caches-home:"$cachesFolder" --settings:"$settingsFile" --verbosity:INFO
         # --no-buildin-settings
        if(!$?) {
            Write-Information ">>>>> Code Cleanup failed"
            throw "Code Cleanup for project failed"
            return $false
        }
    }

    # Cleanup the solution
    dotnet jb cleanupcode --profile="Full Cleanup" $solutionFile --properties:Configuration=Release --properties:nodeReuse=False --caches-home:"$cachesFolder" --settings:"$settingsFile" --verbosity:INFO
     
     # --no-buildin-settings
    if(!$?) {
        Write-Information ">>>>> Code Cleanup failed"
        throw "Code Cleanup for solution failed"
    }

    Write-Information "* Building after cleanup"
    $buildOk = DotNet-BuildSolution -srcFolder $sourceFolder
    if($buildOk) {
        return $true
    }

    Write-Information ">>>>> Build Failed! [From Cleanup]"
    return $false
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

    $lastRevision = Tracking_Get -basePath $root -repo $repo
    $currentRevision = Git-Get-HeadRev

    Write-Information "Last Revision:    $lastRevision"
    Write-Information "Current Revision: $currentRevision"

    if( $lastRevision -eq $currentRevision) {
        Write-Information "Repo not changed"
    }

    $hasCleanedSuccessFully = $false
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
                if($cleaned -eq $null) {
                    Git-ResetToMaster
                    continue
                }

                if($cleaned) {
                    $hasCleanedSuccessFully = $true

                    Set-Location -Path $repoFolder

                    $hasChanges = Git-HasUnCommittedChanges
                    if($hasChanges -eq $true) {
                        Git-CreateBranch -branchName $branchName
                        Git-Commit -message "[FF-2244] - Code cleanup on $solutionName"
                        Git-PushOrigin -branchName $branchName
                        
                        Git-ReNormalise
                    }
                }
                else {
                    $branchName = "broken/$currentRevision/cleanup/ff-2244/$solutionName"
                    $branchExists = Git-DoesBranchExist -branchName $branchName
                    if($branchExists -ne $true) {
                        $hasChanges = Git-HasUnCommittedChanges
                        if($hasChanges -eq $true) {
                            Git-CreateBranch -branchName $branchName
                            Git-Commit -message "[FF-2244] - Code cleanup on $solutionName [BROKEN - NEEDS INVESTIGATION - DO NOT MERGE]"
                            Git-PushOrigin -branchName $branchName
                            
                            Git-ReNormalise
                        }
                    }
                }

                Git-ResetToMaster
            }
        }    
    }

    if($hasCleanedSuccessFully -eq $true) {
        Write-Information "Updating Tracking for $repo to $currentRevision"
        Tracking_Set -basePath $root -repo $repo -value $currentRevision
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

Write-Information ">>>>>>>>>>>> ALL REPOS PROCESSED <<<<<<<<<<<<"