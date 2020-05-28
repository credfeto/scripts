<#
 .Synopsis
  Exports the release notes from a CHANGELOG.md file

 .Description
  Exports the release notes from a CHANGELOG.md file

 .Parameter fileName
  The CHANGELOG.md file to read

 .Parameter buildNumber
  The Build to get the changelog entries for.
#>
function ChangeLog-ExtractReleaseNotes {
param(
    [string] $fileName,
    [string] $buildNumber
    )
     
    if($buildNumber.Contains('-'))
    {
        $buildNumber = "unreleased"
    }
    else
    {
        $buildNumber = $buildNumber.Substring(0, $buildNumber.LastIndexOf('.'))
    }

    #Write-Host "Source Build:" $buildNumber

    $text = Get-Content $fileName

    $foundStart = -1
    $foundEnd = -1
    for($i=1; $i -lt $text.Length; $i++)
    {
        if($text[$i].ToLower().StartsWith("## [" + $buildNumber)) {
            $foundStart = $i+ 1
            Continue
        }
    
        if( $foundStart -ne -1 -and $text[$i].StartsWith("## ["))
        {
            $foundEnd = $i
            Break
        }
    }

    $releaseNotes = ""
    if($foundStart -ne -1) {
        if($foundEnd -eq -1) {
            $foundEnd = $text.Length
        }

        $previousLine = ""
        for($i=$foundStart; $i -lt $foundEnd; $i++)
        {
		    if($text[$i] -eq "")
            {
                Continue
            }

            if($text[$i].StartsWith("### ") -and $previousLine.StartsWith("### "))
            {
                $previousLine = $text[$i]
                Continue
            }

            if($text[$i].StartsWith("### "))
            {
                $previousLine = $text[$i]
                Continue
            }

            if($previousLine.StartsWith("### "))
            {
                #Write-Host $previousLine
                $releaseNotes = $releaseNotes +"`n" + $previousLine
            }

            #Write-Host $text[$i]
            $releaseNotes = $releaseNotes +"`n" + $text[$i]
            $previousLine = $text[$i]
        }
    }

    if($buildNumber -eq "unreleased")
    {
        $releaseNotes = $releaseNotes -replace '(?ms)<!--(.*)-->', ''
    }

    
    return $releaseNotes.Trim()
}

<#
 .Synopsis
  Creates an empty CHANGELOG.md file

 .Description
  Creates an empty CHANGELOG.md file

 .Parameter fileName
  The CHANGELOG.md file to create
#>
function ChangeLog-CreateEmpty {
param(
    [string] $fileName
    )

$output = "# Changelog
All notable changes to this project will be documented in this file.

<!--
Please ADD ALL Changes to the UNRELASED SECTION and not a specific release
-->

## [Unreleased]
### Added
### Fixed
### Changed
### Removed
### Deployment Changes

<!-- 
Releases that have at least been deployed to staging, BUT NOT necessarily released to live.  Changes should be moved from [Unreleased] into here as they are merged into the appropriate release branch
-->
## [0.0.0] - Project created
"

    Write-Host "* Creating Empty Changelog"
    Set-Content -Path $fileName -Value $output
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
    [string] $fileName, 
    [string] $entryType, 
    [string] $code, 
    [string] $message
    )
    
    Write-Host ">>> Updating Changelog <<<"

    $changeLogExists = Test-Path -path $fileName
    if ($changeLogExists -ne $true)
    {
        ChangeLog-CreateEmpty -fileName $fileName
    }


    $text = Get-Content $fileName

    $output = ""
    $foundUnreleased = $false
    $done = $false

    $newline = "`n"

    for($i=0; $i -lt $text.Length; $i++)
    {
        $line = $text[$i].TrimEnd()
        $output = $output + $line + $newline
        if($done -eq $true) {
            Continue
        }

        if($foundUnreleased -eq $false) {
            if($line -eq "## [Unreleased]") {
                $foundUnreleased = $true
                Continue
            }
        }
        else {
            if( $line -eq "### $entryType") {
                Write-Host "* Changelog Insert position added"
                $output = $output + "- $code - $message" + $newline 
                $done = $true;
            }
        }
    }

    if($done -eq $true) {
        Write-Host "* Saving Changelog"
        Set-Content -Path $fileName -Value $output
    }
    else {
        Write-Host "* Changelog NOT Updated"
    }

}

Export-ModuleMember -Function ChangeLog-ExtractReleaseNotes
Export-ModuleMember -Function ChangeLog-CreateEmpty
Export-ModuleMember -Function ChangeLog-AddEntry
