
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

Export-ModuleMember -Function Packages_Get
Export-ModuleMember -Function Packages_ShouldUpdate