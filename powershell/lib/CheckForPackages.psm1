
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

function WriteLogs {
    param(
    [string[]]$logs
    )
    
    foreach($message in $logs)
    {
        Write-Information $message
    }
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
        Write-Information "Excluding: $excluded"
       
        return $excludes
    }
    else {
        Write-Information "Excluding: <<None>>"
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

    Write-Information "Updating Package Exact"
    $search = buildPackageSearch -packageId $packageId -exactMatch $True
    $excludes = buildExcludes -exclude $exclude
    if($excludes) {
        $results = dotnet updatepackages --cache $packageCache --folder $repoFolder --package-id $search --exclude $excludes
    }
    else {
        $results = dotnet updatepackages --cache $packageCache --folder $repoFolder --package-id $search
    }    
    if ($?)
    {
        WriteLogs -logs $results
        
        # has updates
        [string]$packageIdAsRegex = $packageId.Replace(".", "\.").ToLower()
        [string]$regexPattern = "::set-env name=$packageIdAsRegex::(?<Version>\d+(\.\d+)+)"

        $regex = new-object System.Text.RegularExpressions.Regex($regexPattern, [System.Text.RegularExpressions.RegexOptions]::MultiLine)
        $regexMatches = $regex.Matches($results.ToLower());
        if($regexMatches.Count -gt 0) {
            [string]$version = $regexMatches[0].Groups["Version"].Value
            Write-Information "Found: $version"
            return $version
        }
        
        Write-Information " * No Changes"    
    }
    else
    {
        Write-Information " * ERROR: Failed to update $packageId"    
        WriteLogs -logs $results
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

    Write-Information "Updating Package Prefix"
    $search = buildPackageSearch -packageId $packageId -exactMatch $False
    $excludes = buildExcludes -exclude $exclude
    if($excludes) {
        $results = dotnet updatepackages --cache $packageCache --folder $repoFolder --package-id $search --exclude $excludes
    }
    else {
        $results = dotnet updatepackages --cache $packageCache --folder $repoFolder --package-id $search
    }

    if($?) {
        
        WriteLogs -logs $results
        
        # has updates
        [string]$packageIdAsRegex = $packageId.Replace(".", "\.").ToLower()
        [string]$regexPattern = "echo ::set-env name=$packageIdAsRegex(.*?)::(?<Version>\d+(\.\d+)+)"

        $regex = new-object System.Text.RegularExpressions.Regex($regexPattern, [System.Text.RegularExpressions.RegexOptions]::MultiLine)
        $regexMatches = $regex.Matches($results.ToLower());
        if($regexMatches.Count -gt 0) {
            [string]$version = $regexMatches[0].Groups["Version"].Value
            Write-Information "Found: $version"
            return $version
        }
    }
    else
    {
        WriteLogs -logs $results
    }
    
    Write-Information " * No Changes"    
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