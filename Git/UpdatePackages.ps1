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

function findPreReleasePackageVersion( $packageId) {

    Write-Host "Looking for latest version of $packageId (Includes pre-release)"

    $packageIdRegex = $packageId.Replace(".", "\.")

    $entry = &%teamcity.tool.NuGet.CommandLine.DEFAULT%\tools\nuget.exe list PackageId:$packageId -prerelease | ? { $_ -match "^" + $packageIdRegex + "\s+(\d+\..*)$" }
    
    if($entry -eq $null) {
        return $null
    }


    $splitEntry = $entry.Split(' ')
    $id = $splitEntry[0]
    $version = $splitEntry[1]

    return $version
}

function isInstalled($packageId) {
    $packageIdRegex = $packageId.Replace(".", "\.").ToLowerInvariant();

    $entry = &dotnet tool list --local | ? { $_ -match "^" + $packageIdRegex + "\s+(\d+\..*)$" }

	Write-Host "Found: $entry"
    return $entry -ne $null;
}

function removeTool($packageId) {

    if(isInstalled -packageId $packageId) {

        Write-Host "Removing currently installed $packageId"
        dotnet tool uninstall --local $packageId
    }
}


function installTool($packageId, $preReleaseVersion) {

    $manifestExists = Test-Path -path '.config\dotnet-tools.json'
    if ($manifestExists -ne $true)
    {
        dotnet new tool-manifest
    }

    removeTool -packageId $packageId

    if($preReleaseVersion -eq $true) {
        $version = findPreReleasePackageVersion -packageId $packageId

        if( $version -ne $null) {
            Write-Host "Installing $version of $packageId"
            dotnet tool install --local $packageId --version $version
            
            $installed = isInstalled -packageId $packageId
			return $installed
        }
    }

    Write-Host "Installing latest release version of $packageId"
    dotnet tool install --local $packageId
    
    $installed = isInstalled -packageId $packageId
	return $installed
}

$installed = installTool -packageId $packageIdToInstall -preReleaseVersion $preRelease

if($installed -eq $false) {
    Write-Error ""
	Write-Error "#teamcity[buildStatus status='FAILURE' text='Failed to install $packageIdToInstall']
   } else {
   Write-Host "#teamcity[buildStatus status='SUCCESS' text='Package $packageIdToInstall installed']
   
}

function resetToMaster() {

    # junk any existing checked out files
    & $git reset head --hard
    & $git clean -f -x -d
    & $git checkout master
    & $git reset head --hard
    & $git clean -f -x -d
    & $git fetch

    # NOTE Loses all local commmits on master
    & $git reset --hard origin/master
    & $git remote update origin --prune
    & $git prune
    & $git gc --aggressive --prune
}

function ensureSynchronised($repo, $repofolder) {

    $githead = Join-Path -Path $repoFolder -ChildPath ".git" 
    $githead = Join-Path -Path $githead -ChildPath "HEAD" 
    
    Write-Host $githead
    $gitHeadCloned = Test-Path -path $githead

    if ($gitHeadCloned -eq $True) {
        Write-Host "Already Cloned"
        Set-Location $repofolder

        resetToMaster
    }
    else
    {
        & $git clone $repo
        
    }
}

function buildSolution($repoFolder) {

    $srcFolder = Join-Path -Path $repoFolder -ChildPath "src"
    Set-Location $srcFolder

    Write-Host "Building Source in $srcFolder"
    Write-Host " * Cleaning"
    dotnet clean --configuration=Release 
    if(!$?) {
        # Didn't Build
        return $false;
    }

    Write-Host " * Restoring"
    dotnet restore
    if(!$?) {
        # Didn't Build
        return $false;
    }

    Write-Host " * Building"
    dotnet build --configuration=Release --no-restore -warnAsError
    if(!$?) {
        # Didn't Build
        return $false;
    }

    # Should test here too?

    return $true;
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


$repoList = Get-Content $repos | Select-Object
$packages = Get-Content $packagesToUpdate| Out-String | ConvertFrom-Json

Write-Host $packages.Length
for($i = 0; $i -lt $packages.Length; ++$i){
    Write-Host $packages[$i].packageId
}


ForEach($repo in $repoList) {
    processRepo -repo $repo -packages $packages
}

Set-Location $root





#$repos | ConvertFrom-Json

