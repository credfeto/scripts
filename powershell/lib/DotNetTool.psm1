
$standardSource = 'https://api.nuget.org/v3/index.json'

function DotNetTool-Error {
param($result)

    foreach($line in $result) {
        Write-Error $line
    }
}

function getLatestReleasePackage($packageId) {

	try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Log -message "Looking for $packageId in $standardSource"
        $packages = Find-Package -Name $packageId -Source $standardSource -AllVersions -ProviderName NuGet -ErrorAction:SilentlyContinue 
        if($packages) {
        
            foreach($package in $packages) {
                $version = $package.Version
                Log -message "* Found $packageId version $version"
                return $version
            }
            
			[string]$foundVersion = $packages[0].Version
			Log -message "* Found $foundVersion"
            return $foundVersion
        }

		Log -message "- Not Found"
        return $null
	}
	catch {
		Log -message "# Not Found - Error"
		return $null
	}
}


function getLatestPreReleasePackage($packageId) {

	try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Log -message "Looking for $packageId in $standardSource"
        $packages = Find-Package -Name $packageId -Source $standardSource -AllowPrereleaseVersions -ProviderName NuGet -ErrorAction:SilentlyContinue 
        if($packages) {
            foreach($package in $packages) {
                $version = $package.Version
                Log -message "* Found $packageId version $version"
                if($version -lt "100.0.0.0") {
                    Log -message "* Found $packageId version $version"
                    return $version
                }
            }
                    
			[string]$foundVersion = $packages[0].Version
			Log -message "* Found $foundVersion"
            return $foundVersion
        }

		Log -message "- Not Found"
        return $null
	}
	catch {
		Log -message "# Not Found - Error"
		return $null
	}
}

function findPreReleasePackageVersion( $packageId) {

    Log -message "Looking for latest version of $packageId (Includes pre-release)"

    [string]$package = getLatestPreReleasePackage -packageId $packageId
    if($package) {
        return $package
    }

    return $null
}

function isInstalled($packageId) {
    [string]$packageIdRegex = $packageId.Replace(".", "\.").ToLowerInvariant();

    $result = &dotnet tool list --local
    $entry = $result | ? { $_ -match "^" + $packageIdRegex + "\s+(\d+\..*)$" }

	Log -message "Found: $entry"
	
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
    [string] $packageId = $(throw "DotNetTool-Uninstall: packageId not specified")
    )

    if(isInstalled -packageId $packageId) {

        Log -message "Removing currently installed $packageId"
        [string[]]$result = dotnet tool uninstall --local $packageId
        if(!$?) {
            DotNetTool-Error -result $result
            throw "Failed to uninstall $packageId"
        }
        Log-Batch -messages $result
    }
}

function DotNetTool-InstallVersion {
param(
    [string] $packageId = $(throw "DotNetTool-InstallVersion: packageId not specified"),
    [string] $version = $(throw "DotNetTool-InstallVersion: Version not specified")
    )

    Log -message "Installing $version of $packageId"
    [string[]]$result = dotnet tool install --local $packageId --version $version
    if(!$?) {
        DotNetTool-Error -result $result
        return $false
    }
    
    Log-Batch -messages $result
    
    [bool]$installed = isInstalled -packageId $packageId
    return [bool]$installed    
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
    [string] $packageId = $(throw "DotNetTool-Install: packageId not specified"),
    [bool] $preReleaseVersion = $false
    )

    [bool]$manifestExists = Test-Path -path '.config\dotnet-tools.json'
    if ($manifestExists -ne $true)
    {
        [string[]]$result = dotnet new tool-manifest
        if(!$?) {
            DotNetTool-Error -result $result
            throw "Failed to uninstall $packageId"
        }
        
        Log-Batch -messages $result
    }

    # Uninstall if already installed 
    [bool]$installed = isInstalled -packageId $packageId
    if($installed) {
        DotNetTool-Uninstall -packageId $packageId
    }
    
#     if($packageId -eq "Credfeto.ChangeLog.Cmd") {
#         return DotNetTool-InstallVersion -packageId $packageId -version "1.10.6.22"
#     }
#     
#     if($packageId -eq "Funfair.BuildVersion") {
#         return DotNetTool-InstallVersion -packageId $packageId -version "6.2.0.963"
#     }
#     
#     if($packageId -eq "FunFair.BuildCheck") {
#         return DotNetTool-InstallVersion -packageId $packageId -version "6.3.5.1415"
#     }

    # Install pre-release if requested
    if($preReleaseVersion -eq $true) {
        [string]$version = findPreReleasePackageVersion -packageId $packageId

        if($version -ne $null) {
            Log -message "Installing $version of $packageId"
            [string[]]$result = dotnet tool install --local $packageId --version $version
            if(!$?) {
                DotNetTool-Error -result $result
                return $false
            }
            
            Log-Batch -messages $result
            
            [bool]$installed = isInstalled -packageId $packageId
			return [bool]$installed
        }
    }
    
    if($packageId -eq "funfair.buildcheck") {
        Log -message "Installing latest version of $packageId"
        $latestReleaseVersion = getLatestReleasePackage -packageId $packageId

        [string[]]$result = dotnet tool install --local $packageId --version $latestReleaseVersion
        if(!$?) {
            DotNetTool-Error -result $result
            return $false
        }
        
        [bool]$installed = isInstalled -packageId $packageId
        return [bool]$installed
    }
        
    # Install released version
    Log -message "Installing latest release version of $packageId"
    [string[]]$result = dotnet tool install --local $packageId
    if(!$?) {
        DotNetTool-Error -result $result
        return $false
    }
    
    [bool]$installed = isInstalled -packageId $packageId
	return [bool]$installed
}

function DotNetTool-IsInstalled{
param(
    [string] $packageId = $(throw "DotNetTool-Install: packageId not specified")
)
    
    [string[]] $result = dotnet tool list
    if(!$?) {
        DotNetTool-Error -result $result
        throw "Failed to list installed packages $packageId"
    }
    
    Log-Batch -messages $result
    
    $lowerPackageId = $packageId.ToLower() + " "
    
    foreach($line in $result) {
        $lowerLine = $line.ToLower()
        if($line.StartsWith($lowerPackageId)) {
            return $true
        }
    }
    
    return $false
}

function DotNetTool-Require{
param(
    [string] $packageId = $(throw "DotNetTool-Install: packageId not specified")
)
    Log -message "Checking that $packageId is installed..."
    $installed = DotNetTool-IsInstalled -packageId $packageId
    
    if(!$installed) {
        throw "Package $packageId is not installed"
    }
    
    Log -message "$packageId found"
    [string[]]$restored = dotnet tool restore
    Log-Batch -messages $restored
}

Export-ModuleMember -Function DotNetTool-Install
Export-ModuleMember -Function DotNetTool-Uninstall
Export-ModuleMember -Function DotNetTool-IsInstalled
Export-ModuleMember -Function DotNetTool-Require
