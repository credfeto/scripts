function BuildVersion-IsMissingTool {
param(
    [string[]]$result
    )
    
    foreach($line in $result) {
        Log -message $line
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
    DotNetTool-Require -packageId "FunFair.BuildVersion"
    
    [string[]]$result = dotnet buildversion --BuildNumber 9999 --WarningsAsErrors

    if(!$?) {
        Log-Batch -messages $result
        BuildVersion-IsMissingTool -result $result
        throw "Could Not Determine Release (command failed)"
    }

    Log-Batch -messages $result

    $match = select-string "Version:\s(\d+\.\d+\.\d+)\.\d+\-[master|main]" -InputObject $result
    if($match) {
        [string]$version = $match.Matches.Groups[1].Value
        Log -message "Found Release Branch ($version)"
        return $version
    }

    return [string]$null
}

Export-ModuleMember -Function BuildVersion-GetNextPatch
