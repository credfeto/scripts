<#
 .Synopsis
  Gets the next patch release version

 .Description
  Gets the next patch release version
#>
function BuildVersion-GetNextPatch {
    $result = dotnet buildversion --BuildNumber 9999 --WarningsAsErrors

    if(!$?) {
        Write-Error $result
        throw "Could Not Determine Release (command failed)"
    }
    
    Write-Information $result

    $match = select-string "Version:\s(\d+\.\d+\.\d+)\.\d+\-master" -InputObject $result
    if($match) {
        $version = $match.Matches.Groups[1].Value
        Write-Information "Found Release Branch ($version)"
        return $version
    }

    return $null
}

Export-ModuleMember -Function BuildVersion-GetNextPatch
