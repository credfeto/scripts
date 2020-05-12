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
