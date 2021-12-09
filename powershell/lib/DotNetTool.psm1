
$standardSource = 'https://api.nuget.org/v3/index.json'

function getLatestPreReleasePackage($packageId) {

	try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Write-Information "Looking for $packageId in $standardSource"
        $packages = Find-Package -Name $packageId -Source $standardSource -AllowPrereleaseVersions -ProviderName NuGet -ErrorAction:SilentlyContinue 
        if($packages) {
			[string]$foundVersion = $packages[0].Version
			Write-Information "* Found $foundVersion"
            return $foundVersion
        }

		Write-Information "- Not Found"
        return $null
	}
	catch {
		Write-Information "# Not Found - Error"
		return $null
	}
}

function findPreReleasePackageVersion( $packageId) {

    Write-Information "Looking for latest version of $packageId (Includes pre-release)"

    [string]$package = getLatestPreReleasePackage -packageId $packageId
    if($package) {
        return $package
    }

    return $null
}

function isInstalled($packageId) {
    [string]$packageIdRegex = $packageId.Replace(".", "\.").ToLowerInvariant();

    $entry = &dotnet tool list --local | ? { $_ -match "^" + $packageIdRegex + "\s+(\d+\..*)$" }

	Write-Information "Found: $entry"
	
	if($entry -ne $null) {
	    return $true
	}
	
    return $false
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

    [bool]$manifestExists = Test-Path -path '.config\dotnet-tools.json'
    if ($manifestExists -ne $true)
    {
        dotnet new tool-manifest
    }

    # Uninstall if already installed 
    [bool]$installed = isInstalled -packageId $packageId
    if($installed) {
        DotNetTool-Uninstall -packageId $packageId
    }

    # Install pre-release if requested
    if($preReleaseVersion -eq $true) {
        [string]$version = findPreReleasePackageVersion -packageId $packageId

        if($version -ne $null) {
            Write-Information "Installing $version of $packageId"
            dotnet tool install --local $packageId --version $version
            if(!$?) {
                return $false
            }
            
            [bool]$installed = isInstalled -packageId $packageId
			return [bool]$installed
        }
    }

    # Install released version
    Write-Information "Installing latest release version of $packageId"
    dotnet tool install --local $packageId
    if(!$?) {
        return $false
    }
    
    [bool]$installed = isInstalled -packageId $packageId
	return [bool]$installed
}

Export-ModuleMember -Function DotNetTool-Install
Export-ModuleMember -Function DotNetTool-Uninstall
