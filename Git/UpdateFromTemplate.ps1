#########################################################################

$ErrorActionPreference = "Stop" 
$templateRepo = "%TEMPLATE%"
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

function updateFileAndCommit($srcRepo, $targetRepo, $filename, $message) {
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
    updatefileandcommit -srcRepo $srcRepo -targetRepo $folder -fileName ".editorconfig"
    updatefileandcommit -srcRepo $srcRepo -targetRepo $folder -fileName ".gitleaks.toml"
    updatefileandcommit -srcRepo $srcRepo -targetRepo $folder -fileName "src\CodeAnalysis.ruleset"
    updatefileandcommit -srcRepo $srcRepo -targetRepo $folder -fileName "src\global.json"
    updatefileandcommit -srcRepo $srcRepo -targetRepo $folder -fileName ".github\pr-lint.yml"
    updatefileandcommit -srcRepo $srcRepo -targetRepo $folder -fileName ".github\CODEOWNERS"
    updatefileandcommit -srcRepo $srcRepo -targetRepo $folder -fileName ".github\PULL_REQUEST_TEMPLATE.md"
    updatefileandcommit -srcRepo $srcRepo -targetRepo $folder -fileName ".dependabot\config.yml"
    updatefileandcommit -srcRepo $srcRepo -targetRepo $folder -fileName ".github\workflows\cc.yml"
    updatefileandcommit -srcRepo $srcRepo -targetRepo $folder -fileName ".github\workflows\dependabot-auto-merge.yml"

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
ForEach($repo in $repoList) {
    processRepo -template $template -repo $repo -packages $packages
}

Set-Location $root

