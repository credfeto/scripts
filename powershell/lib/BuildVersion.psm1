function BuildVersion-IsMissingTool {
param(
    [string[]]$result
    )
    
    foreach($line in $result) {
        if($line.Contains("dotnet tool restore")) {
            dotnet tool list
            throw "Missing dotnet tool"
        }
    }
}

<#
 .Synopsis
  Gets the next patch release version

 .Description
  Gets the next patch release version
#>
function BuildVersion-GetNextPatch {
    $result = dotnet buildversion --BuildNumber 9999 --WarningsAsErrors

    if(!$?) {
        foreach($line in $result) {
            Write-Information $line
        }
        BuildVersion-IsMissingTool -result $result
        throw "Could Not Determine Release (command failed)"
    }
    
    foreach($line in $result) {
        Write-Information $line
    }

    $match = select-string "Version:\s(\d+\.\d+\.\d+)\.\d+\-[master|main]" -InputObject $result
    if($match) {
        [string]$version = $match.Matches.Groups[1].Value
        Write-Information "Found Release Branch ($version)"
        return $version
    }

    return [string]$null
}

Export-ModuleMember -Function BuildVersion-GetNextPatch
