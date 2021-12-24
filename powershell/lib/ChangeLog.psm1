function Changelog-Log {
param(
    [string[]]$result
    )
    
    foreach($line in $result) {
        Write-Information $line
    }
}

<#
 .Synopsis
  Adds an entry to the [Unreleased] section of a CHANGELOG.md file.

 .Description
  Adds an entry to the [Unreleased] section of a CHANGELOG.md file

 .Parameter fileName
  The CHANGELOG.md file to update (if it doesn't exist a new one is created

 .Parameter entryType
  The type of entry to add (Added, Fixed, Changed, Removed, Deployment Changes)

  .Parameter code
  The code for the change e.g XX-1234

  .Parameter message
  The message/description of the change
#>
function ChangeLog-AddEntry {
param(
    [string] $fileName = $(throw "fileName not specified"), 
    [string] $entryType = $(throw "entryType not specified"), 
    [string] $code = $(throw "code not specified"), 
    [string] $message = $(throw "message not specified")
    )
    
    Write-Information ">>> Updating Changelog <<<"

    [string[]]$result = dotnet changelog --changelog $fileName --add $entryType --message "$code - $message"
    Changelog-Log -result $result
    if($?) {
        Write-Information "* Changelog Updated"
    }
    else {
        Write-Information "* Changelog NOT Updated"
        throw "Failed to update changelog"
    }
}

function ChangeLog-CreateRelease {
    param(
        [string] $fileName = $(throw "fileName not specified"),
        [string] $release = $(throw "release not specified")
    )

    Write-Information ">>> Creating Changelog release notes for $release <<<"

    [string[]]$result = dotnet changelog --changelog $fileName --create-release $release
    Changelog-Log -result $result
    if($?) {
        Write-Information "* Changelog Updated"
    }
    else {
        Write-Information "* Changelog NOT Updated"
        throw "Failed to update changelog"
    }
}

function ChangeLog-GetUnreleased {
    param(
        [string] $fileName = $(throw "fileName not specified")
    )

    Write-Information ">>> Reading Changelog unreleased content <<<"

    [string[]]$releaseNotes = dotnet changelog --changelog $fileName --un-released $release
    if($?) {

        [int]$skip = 0
        while($skip -lt $releaseNotes.Length -and !$releaseNotes[$skip].StartsWith("#"))
        {
            ++$skip
        }

        [string[]]$releaseNotes = $releaseNotes | Select-Object -Skip $skip

        return $releaseNotes

    }
    else {
        Write-Information "* Changelog NOT extracted"
        throw "Failed to extract changelog"
    }
}



Export-ModuleMember -Function ChangeLog-AddEntry
Export-ModuleMember -Function ChangeLog-CreateRelease
Export-ModuleMember -Function ChangeLog-GetUnreleased