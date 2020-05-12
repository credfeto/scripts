#########################################################################

$ErrorActionPreference = "Stop" 
$packageIdToInstall = "Credfeto.Package.Update"
$preRelease = "False"
$repos = "repos.lst"
$packagesToUpdate = "packages.json" 
$root = Get-Location
$git="git"
Write-Host $root

$env:GIT_REDIRECT_STDERR="2>&1"

#########################################################################

# region Include required files
#
$ScriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
try {
    . ("$ScriptDirectory\DotNetTool.ps1")
    . ("$ScriptDirectory\GitUtils.ps1")
    . ("$ScriptDirectory\DotNetBuild.ps1")
#    . ("$ScriptDirectory\YourFile4.ps1")
}
catch {
    Write-Host "Error while loading supporting PowerShell Scripts" 
}
#endregion


$installed = installTool -packageId $packageIdToInstall -preReleaseVersion $preRelease

if($installed -eq $false) {
    Write-Error ""
	Write-Error "#teamcity[buildStatus status='FAILURE' text='Failed to install $packageIdToInstall']
   } else {
   Write-Host "#teamcity[buildStatus status='SUCCESS' text='Package $packageIdToInstall installed']
   
}



function checkForUpdates($repoFolder, $packageId) {

    dotnet updatepackages -folder $repoFolder -prefix $packageId 

    if($?) {
        # has updates
    }

    return $null
}

function processRepo($repo, $packages) {
    
    Set-Location $root
    
    Write-Host "Processing Repo: $repo"

    # Extract the folder from the repo name
    $folder = $repo.Substring($repo.LastIndexOf("/")+1)
    $folder = $folder.SubString(0, $folder.LastIndexOf("."))

    Write-Host "Folder: $folder"
    $repoFolder = Join-Path -Path $root -ChildPath $folder

    ensureSynchronised -repo $repo -repofolder $repoFolder

    $srcPath = $srcFolder = Join-Path -Path $repoFolder -ChildPath "src"
    $srcExists = Test-Path -Path $srcPath
    if($srcExists -eq $false) {
        # no source to update
        return;
    }

    $codeOK = buildSolution -repoFolder $repoFolder
    if( $codeOk -eq $false) {
        # no point updating
        return;
    }


    ForEach($package in $packages) {
        Write-Host 'Looking for updates of' $package.packageId
        $update = checkForUpdates -repoFolder $repoFolder -packageId $package.packageId
        Write-Host $update
    }
}



$packages = Get-Content $packagesToUpdate| Out-String | ConvertFrom-Json

$repoList = loadRepoList -repos $repos
ForEach($repo in $repoList) {
    processRepo -repo $repo -packages $packages
}

Set-Location $root





#$repos | ConvertFrom-Json

