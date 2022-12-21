
function Packages_Get {
param (
    [string]$fileName = $(throw "Packages_Get: fileName not specified")
)
    $packages = Get-Content -Path $fileName -Raw | ConvertFrom-Json
    
    return $packages
}

Export-ModuleMember -Function Packages_Get