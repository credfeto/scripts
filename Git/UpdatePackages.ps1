﻿#########################################################################

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
    . ( Join-Path -Path $ScriptDirectory -ChildPath "DotNetTool.ps1")
    . (Join-Path -Path $ScriptDirectory -ChildPath "GitUtils.ps1")
    . (Join-Path -Path $ScriptDirectory -ChildPath "DotNetBuild.ps1")
}
catch {
    Write-Host "Error while loading supporting PowerShell Scripts" 
}
#endregion


function checkForUpdates($repoFolder, $packageId) {

    $results = dotnet updatepackages -folder $repoFolder -prefix $packageId 

    if($?) {
        
        # has updates
        $packageIdAsRegex = $packageId.Replace(".", "\.")

        if($results -match "^echo ::set-env name=$packageIdAsRegex::(?<Version>\d+(\.\d+)+)$") {
            Write-Host " * Found" $Matches.Version
            return $Matches.Version
        }
        else {
            Write-Host " * Updates found"
            return "latest"
        }
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
        $packageId = $package.packageId
        $type = $package.type

        Write-Host 'Looking for updates of $packageId' 
        $update = checkForUpdates -repoFolder $repoFolder -packageId $package.packageId
        Write-Host $update

        $codeOK = buildSolution -repoFolder $repoFolder
        if($codeOK -eq $true) {
            commit -message "[FF-1429] Updating $packageId ($type) to $update"
            push
        }
    }
}

#########################################################################


$installed = installTool -packageId $packageIdToInstall -preReleaseVersion $preRelease

if($installed -eq $false) {
    Write-Error ""
	Write-Error "#teamcity[buildStatus status='FAILURE' text='Failed to install $packageIdToInstall']"
}


$packages = Get-Content $packagesToUpdate| Out-String | ConvertFrom-Json

$repoList = loadRepoList -repos $repos
ForEach($repo in $repoList) {
    processRepo -repo $repo -packages $packages
}

Set-Location $root





#$repos | ConvertFrom-Json

