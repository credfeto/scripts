﻿<#
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
    [string] $fileName, 
    [string] $entryType, 
    [string] $code, 
    [string] $message
    )
    
    Write-Information ">>> Updating Changelog <<<"

    dotnet changelog --changelog $fileName --add $entryType --message "$code - $message"
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
        [string] $fileName,
        [string] $release
    )

    Write-Information ">>> Creating Changelog release notes for $release <<<"

    dotnet changelog --changelog $fileName --create-release $release
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
        [string] $fileName
    )

    Write-Information ">>> Reading Changelog unreleased content <<<"

    $releaseNotes = dotnet changelog --changelog $fileName --un-released $release
    if($?) {

        $skip = 0
        while($skip -lt $releaseNotes.Length -and !$releaseNotes[$skip].StartsWith("#"))
        {
            ++$skip
        }

        $releaseNotes = $releaseNotes | Select-Object -Skip $skip

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