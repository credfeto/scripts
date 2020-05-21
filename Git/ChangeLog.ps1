function extractReleaseNotes($fileName, $buildNumber) {
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

function CreateEmptyChangelog($fileName) {

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

function UpdateChangelog($fileName, $entryType, $code, $message) {
    Write-Host ">>> Updating Changelog <<<"

    $changeLogExists = Test-Path -path $fileName
    if ($changeLogExists -ne $true)
    {
        CreateEmptyChangelog -fileName $fileName
    }


    $text = Get-Content $fileName

    $output = ""
    $foundUnreleased = $false
    $done = $false

    for($i=1; $i -lt $text.Length; $i++)
    {
        $line = $text[$i].TrimEnd()
        $output = $output + $line + "`n"
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
                $output = $output + "- $code - $message`n"
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