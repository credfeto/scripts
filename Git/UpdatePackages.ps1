#########################################################################

$packageIdToInstall = "Credfeto.Package.Update"
$preRelease = "False"
$repos = "repos.lst"
$packagesToUpdate = "packages.json" 


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

function processRepo($repo, $packages) {
    Write-Host $repo

#    for($i = 0; $i -lt $packages.Length; ++$i){
#        $package = $packages[$i]
#        Write-Host $packages.packageId
#    }

    ForEach($package in $packages) {
        Write-Host ' -> ' $package.packageId
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





#$repos | ConvertFrom-Json

