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
    [string] $fileName, 
    [string] $entryType, 
    [string] $code, 
    [string] $message
    )
    
    Write-Information ">>> Updating Changelog <<<"

    dotnet changelog -changelog $fileName -add $entryType -message "$code - $message"
    if($?) {
        Write-Information "* Changelog Updated"
    }
    else {
        Write-Information "* Changelog NOT Updated"
        throw "Failed to update changelog"
    }
}

Export-ModuleMember -Function ChangeLog-AddEntry
