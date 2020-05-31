#########################################################################

param(
    [string] $repos = $(throw "repos.lst file containing list of repositories")
)

$ErrorActionPreference = "Stop" 
$root = Get-Location
Write-Host $root

$clt = $env:RESHARPER_COMMAND_LINE_TOOLS
if(clt -eq "") {
    throw "RESHARPER_COMMAND_LINE_TOOLS not defined"
}

#########################################################################

# region Include required files
#
$ScriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
$ScriptDirectory = Join-Path -Path $ScriptDirectory -ChildPath "Lib" 
try {
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "GitUtils.psm1") -Force -DisableNameChecking
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "DotNetBuild.psm1") -Force -DisableNameChecking
}
catch {
    Throw "Error while loading supporting PowerShell Scripts" 
}
#endregion



function runCodeCleanup($solutionFile) {

    SET SOLUTIONFILE=%~nx1
    ECHO * Performing code cleanup on %SOLUTIONFILE% 
    ECHO * In folder: %SOLUTIONFOLDER%
    pushd %SOLUTIONFOLDER%
    SET CACHESFOLDER=%TEMP%/%~pn1
    SET SETTINGSFILE=%~dpnx1.DotSettings

    $buildOk = DotNet-BuildSolution -srcFolder $sourceFolder
    if($buildOk -ne $true) {
        return $true;
    }


    cleanupcode.exe --profile="Full Cleanup" $solutionFile --properties:Configuration=Release --caches-home:"%CACHESFOLDER%" --settings:"%SETTINGSFILE%" --verbosity:WARN --no-buildin-settings --no-builtin-settings
}


function processRepo($srcRepo, $repo) {
    
    Set-Location $root
    
    Write-Host "Processing Repo: $repo"

    # Extract the folder from the repo name
    $folder = $repo.Substring($repo.LastIndexOf("/")+1)
    $folder = $folder.SubString(0, $folder.LastIndexOf("."))

    Write-Host "Folder: $folder"
    $repoFolder = Join-Path -Path $root -ChildPath $folder

    Git-EnsureSynchronised -repo $repo -repofolder $repoFolder

    #########################################################
    # C# file updates
    $srcPath = Join-Path -Path $repoFolder -ChildPath "src"
    $srcExists = Test-Path -Path $srcPath
    if($srcExists -eq $true) {
        
        $solutions = Get-ChildItem -Path $srcPath -Filter "*.sln"
        foreach($solution in $solutions) {
            $solutionFile = $solution.FullName

        }

    
    }
}


$repoList = Git-LoadRepoList -repos $repos


Set-Location $root
    
Write-Host "Loading template: $templateRepo"

# Extract the folder from the repo name
$templateFolder = $templateRepo.Substring($templateRepo.LastIndexOf("/")+1)
$templateFolder = $templateFolder.SubString(0, $templateFolder.LastIndexOf("."))

Write-Host "Template Folder: $templateFolder"
$templateRepoFolder = Join-Path -Path $root -ChildPath $templateFolder

Git-EnsureSynchronised -repo $templateRepo -repofolder $templateRepoFolder

Set-Location $root

ForEach($repo in $repoList) {
    if($repo.Trim() -eq "") {
        continue
    }

    processRepo -srcRepo $templateRepoFolder -repo $repo
}

Set-Location $root

