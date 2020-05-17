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

function updateFileAndCommit($sourceRepo, $targetRepo, $filename) {

    Write-Host $filename

    $srcPath = Join-Path -Path $sourceRepo -ChildPath $filename
    $trgPath = Join-Path -Path $targetRepo -ChildPath $filename

    Write-Host $srcPath
    Write-Host $trgPath

    #$cp = Copy-Item $srcPath -Destination $trgPath
    #Write-Host $cp
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

    }


    #########################################################
    # SIMPLE OVERWRITE UPDATES
    updatefileandcommit -sourceRepo $srcRepo -targetRepo $repoFolder -fileName ".editorconfig"
    updatefileandcommit -sourceRepo $srcRepo -targetRepo $repoFolder -fileName ".gitleaks.toml"
    updatefileandcommit -sourceRepo $srcRepo -targetRepo $repoFolder -fileName "src\CodeAnalysis.ruleset"
    updatefileandcommit -sourceRepo $srcRepo -targetRepo $repoFolder -fileName "src\global.json"
    updatefileandcommit -sourceRepo $srcRepo -targetRepo $repoFolder -fileName ".github\pr-lint.yml"
    updatefileandcommit -sourceRepo $srcRepo -targetRepo $repoFolder -fileName ".github\CODEOWNERS"
    updatefileandcommit -sourceRepo $srcRepo -targetRepo $repoFolder -fileName ".github\PULL_REQUEST_TEMPLATE.md"
    updatefileandcommit -sourceRepo $srcRepo -targetRepo $repoFolder -fileName ".dependabot\config.yml"
    updatefileandcommit -sourceRepo $srcRepo -targetRepo $repoFolder -fileName ".github\workflows\cc.yml"
    updatefileandcommit -sourceRepo $srcRepo -targetRepo $repoFolder -fileName ".github\workflows\dependabot-auto-merge.yml"

    # for %%w in (%TEMPLATE%\.github\workflows\*.yml) DO call ::updatefileandcommit .github\workflows\%%~nxw


    #REM #########################################################
    #REM # COMPLICATED UPDATES
    #ECHO.
    #echo * Update R# DotSettings
    #for %%g in ("%ROOT%\%FOLDER%\src\*.sln") do copy /y /z %TEMPLATE%\src\FunFair.Template.sln.DotSettings %%g.DotSettings
    #call :commit "Jetbrains DotSettings"


    #ECHO.
    #ECHO * update .github\labeler.yml
    #type %TEMPLATE%\.github\labeler.yml > "%ROOT%\%FOLDER%\.github\labeler.yml"
    #echo. >> "%ROOT%\%FOLDER%\.github\labeler.yml"
    #IF EXIST "%ROOT%\%FOLDER%\.github\labeler.project-specific.yml" type "%ROOT%\%FOLDER%\.github\labeler.project-specific.yml" >> "%ROOT%\%FOLDER%\.github\labeler.yml"

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

