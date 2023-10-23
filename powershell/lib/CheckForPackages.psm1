$regexCache = @{}
$regexOptions = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
# -bor [System.Text.RegularExpressions.RegexOptions]::MultiLine

function getPackageIdRegex {
    param(
        [String]$packageId = $(throw "getPackageIdRegex: packageId not specified"),
        [bool]$exactMatch =  $(throw "getPackageIdRegex: exactMatch not specified")
    )

   # has updates
  [string]$packageIdAsRegex = $packageId.Replace(".", "\.").ToLower()
  [string]$regexPattern = "^::set-env\sname=$packageIdAsRegex(.*?)::(?<Version>\d+(\.\d+)+)$"
  if($exactMatch) {
    $regexPattern = "^::set-env\sname=$packageIdAsRegex::(?<Version>\d+(\.\d+)+)$"
  }

  Log -message ">> Regex: $regexPattern"
  
  return $regexPattern
}


function getPackageRegex {
param(
    [String]$packageId =  $(throw "getPackageRegex: packageId not specified"),
    [bool]$exactMatch =  $(throw "getPackageIdRegex: exactMatch not specified")
)
    $key = $packageId.ToLower()
    if($exactMatch) {
        $key = $key + "**-exact-match"
    }
    if(!$regexCache.Contains($key)) {
        Log -message ">> Creating Regex for $packageId"
        [string]$regexPattern = getPackageIdRegex -packageId $packageId -exactMatch $exactMatch
        $regex = new-object System.Text.RegularExpressions.Regex($regexPattern, $regexOptions)
        $regexCache[$key] = $regex
        
        return $regex
    }else {
        Log -message ">> Using Regex for $packageId"
        $regex = $regexCache[$key]
        
        if(!$regex) {
          throw "Regex not found for $packageId"
        }
    
        return $regex
    }
}

function Packages_Get {
param (
    [string]$fileName = $(throw "Packages_Get: fileName not specified")
)
    $packages = Get-Content -Path $fileName -Raw | ConvertFrom-Json
    
    return $packages
}

function Packages_ShouldUpdate{
param (
    $installed = $(throw "Packages_ShouldUpdate: installed not specified"),
    [string]$packageId = $(throw "Packages_ShouldUpdate: packageId not specified"),
    [bool]$exactMatch
)
    foreach($candidate in $installed) {
        if($packageId -eq $candidate) {
            return $true
        }

        if(!$exactMatch) {
            $test = "$packageId.".ToLower()
            
            if($candidate.ToLower().StartsWith($test)) {
                return $true
            }
        }
    }
    
    return $false
}

function getVersion {
param(
    [string[]]$logs,
    $regex
)
    
    foreach($message in $logs)
    {
        Log -message ">> Searching for $packageId in [$message]"
        $regexMatches = $regex.Matches($message);
        $matchCount = $regexMatches.Count
        #Log -message ">> Found $matchCount matches"
        if($matchCount -gt 0) {
            [string]$version = $regexMatches[0].Groups["Version"].Value
            #Log -message ">>Found: [$version]"
            return $version
        }
    }
    
    return $null
}

function buildPackageSearch{
    param(
        [string]$packageId,
        [bool]$exactMatch
    )
    
    if($exactMatch) {
        return $packageId
    }
    
    return "$($packageId):prefix"
}

function buildExcludes{
param(
    $exclude
    )
    
    $excludes =@()
    foreach($item in $exclude)
    {
        [string]$packageId = $item.packageId
        [boolean]$exactMatch = $item.'exact-match'
        $search = buildPackageSearch -packageId $packageId -exactMatch $exactMatch         
        $excludes += $search
    }
    
    if($excludes.Count -gt 0) {
        $excluded = $excludes -join " "
        Log -message "Excluding: $excluded"
       
        return $excludes
    }
    else {
        Log -message "Excluding: <<None>>"
        return $null        
    }
}


function Packages_CheckForUpdatesExact{
param(
    [String]$repoFolder = $(throw "Packages_CheckForUpdatesExact: repoFolder not specified"),
    [string]$packageCache = $(throw "Packages_CheckForUpdatesExact: packageCache not specified"),
    [String]$packageId = $(throw "Packages_CheckForUpdatesExact: packageId not specified"),
    $exclude    
    )

    Log -message "Updating Package Exact"
    $search = buildPackageSearch -packageId $packageId -exactMatch $True
    $excludes = buildExcludes -exclude $exclude
    if($excludes) {
        DotNetTool-Require -packageId "Credfeto.Package.Update"
        Log -message "dotnet updatepackages --cache $packageCache --folder $repoFolder --package-id $search --exclude $excludes"
        [string[]]$results = dotnet updatepackages --cache $packageCache --folder $repoFolder --package-id $search --exclude $excludes
    }
    else {
        DotNetTool-Require -packageId "Credfeto.Package.Update"
        Log -message "dotnet updatepackages --cache $packageCache --folder $repoFolder --package-id $search"
        [string[]]$results = dotnet updatepackages --cache $packageCache --folder $repoFolder --package-id $search
    }
    
    $exitCode = $?
    Log -message "Result: $exitCode"
    
    if ($exitCode -lt 0) {
        Log -message " * ERROR: Failed to update $packageId"
        Log-Batch -messages $results
        throw "Failed to update $packageId"
    }    
    
    if ($exitCode -gt 0)
    {
        #Log-Batch -messages $results
        
        # has updates?
        $regex = getPackageRegex -packageId $packageId -exactMatch $True
        
        [string]$version = getVersion -logs $results -regex $regex
        if($version -ne $null -and $version -ne "") {
            Log -message "* Found: $version"
            return $version
        } 
        
        Log -message " * No Changes"
    }
    else
    {
        Log -message " * ERROR: Failed to update $packageId"
        Log-Batch -messages $results
    }

    
    return $null
}


function Packages_CheckForUpdatesPrefix{
param(
    [String]$repoFolder = $(throw "checkForUpdatesPrefix: repoFolder not specified"),
    [string]$packageCache = $(throw "Packages_CheckForUpdates: packageCache not specified"),
    [String]$packageId = $(throw "checkForUpdatesPrefix: packageId not specified"),
    $exclude
    )

    Log -message "Updating Package Prefix"
    $search = buildPackageSearch -packageId $packageId -exactMatch $False
    $excludes = buildExcludes -exclude $exclude
    if($excludes) {
        DotNetTool-Require -packageId "Credfeto.Package.Update"
        Log -message "dotnet updatepackages --cache $packageCache --folder $repoFolder --package-id $search --exclude $excludes"
        [string[]]$results = dotnet updatepackages --cache $packageCache --folder $repoFolder --package-id $search --exclude $excludes
    }
    else {
        DotNetTool-Require -packageId "Credfeto.Package.Update"
        Log -message "dotnet updatepackages --cache $packageCache --folder $repoFolder --package-id $search"
        [string[]]$results = dotnet updatepackages --cache $packageCache --folder $repoFolder --package-id $search
    }

    if($?) {
        
        #Log-Batch -messages $results
        
        # has updates?
        $regex = getPackageRegex -packageId $packageId -exactMatch $False
        [string]$version = getVersion -logs $results -regex $regex
        if($version -ne $null -and $version -ne "") {
            Log -message "* Found: $version"
            return $version
        } 
    }
    else
    {
        Log-Batch -messages $results
    }
    
    Log -message " * No Changes"
    return $null
}

function Packages_CheckForUpdates{
param(
    [String]$repoFolder = $(throw "Packages_CheckForUpdates: repoFolder not specified"),
    [string]$packageCache = $(throw "Packages_CheckForUpdates: packageCache not specified"),
    [String]$packageId = $(throw "Packages_CheckForUpdates: packageId not specified"),
    [Boolean]$exactMatch,
    $exclude
)

    if ($exactMatch -eq $true)
    {
        return Packages_CheckForUpdatesExact -repoFolder $repoFolder -packageCache $packageCache -packageId $packageId -exclude $exclude
    }
    else
    {
        return Packages_CheckForUpdatesPrefix -repoFolder $repoFolder -packageCache $packageCache -packageId $packageId -exclude $exclude
    }
}

Export-ModuleMember -Function Packages_Get
Export-ModuleMember -Function Packages_ShouldUpdate
Export-ModuleMember -Function Packages_CheckForUpdates
