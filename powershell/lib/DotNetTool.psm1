
# $privateSource = '....'
$standardSource = 'https://api.nuget.org/v3/index.json'

function getLatestPreReleasePackage($packageId) {

	try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Write-Host "Looking for $packageId in $standardSource"
        $packages = Find-Package -Name $packageId -Source $standardSource -AllowPrereleaseVersions -ProviderName NuGet -ErrorAction:SilentlyContinue 
        if($packages) {
			$foundVersion = $packages[0].Version
			Write-Host "* Found $foundVersion"
            return $foundVersion
        }

#         Write-Host "Looking for $packageId in $privateSource"
#         $packages = Find-Package -Name $packageId -Source $privateSource -AllowPrereleaseVersions -ProviderName NuGet -ErrorAction:SilentlyContinue 
#         if($packages) {
# 			$foundVersion = $packages[0].Version
# 			Write-Host "* Found $foundVersion"
#             return $foundVersion
#         }

		Write-Host "- Not Found"
        return $null
	}
	catch {
		Write-Host "# Not Found - Error"
		return $null
	}
}

function findPreReleasePackageVersion( $packageId) {

    Write-Information "Looking for latest version of $packageId (Includes pre-release)"

    package = getLatestPreReleasePackage -packageId $packageId
    if($package) {
        return $package
    }

    return $null
}

function isInstalled($packageId) {
    $packageIdRegex = $packageId.Replace(".", "\.").ToLowerInvariant();

    $entry = &dotnet tool list --local | ? { $_ -match "^" + $packageIdRegex + "\s+(\d+\..*)$" }

	Write-Information "Found: $entry"
    return $entry -ne $null
}

<#
 .Synopsis
  Uninstalls the specified local DOTNET core tool.

 .Description
  Uninstalls the specified local DOTNET core tool.

 .Parameter packageId
  Package Id of the nuget package that contains the tool.
#>
function DotNetTool-Uninstall {
param(
    [string] $packageId
    )

    if(isInstalled -packageId $packageId) {

        Write-Information "Removing currently installed $packageId"
        dotnet tool uninstall --local $packageId
    }
}


<#
 .Synopsis
  Installs the specified local DOTNET core tool.

 .Description
  Installs the specified local DOTNET core tool.

 .Parameter packageId
  Package Id of the nuget package that contains the tool.

 .Parameter preReleaseVersion
  Whether to install a pre-release version
#>
function DotNetTool-Install {
param(
    [string] $packageId,
    [bool] $preReleaseVersion = $false
    )

    $manifestExists = Test-Path -path '.config\dotnet-tools.json'
    if ($manifestExists -ne $true)
    {
        dotnet new tool-manifest
    }

    DotNetTool-Uninstall -packageId $packageId

    if($preReleaseVersion -eq $true) {
        $version = findPreReleasePackageVersion -packageId $packageId

        if( $version -ne $null) {
            Write-Information "Installing $version of $packageId"
            dotnet tool install --local $packageId --version $version
            
            $installed = isInstalled -packageId $packageId
			return $installed
        }
    }

    Write-Information "Installing latest release version of $packageId"
    dotnet tool install --local $packageId
    
    $installed = isInstalled -packageId $packageId
	return $installed
}

Export-ModuleMember -Function DotNetTool-Install
Export-ModuleMember -Function DotNetTool-Uninstall
