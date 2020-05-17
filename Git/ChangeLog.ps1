function extractReleaseNotes($changeLog, $buildNumber) {
    if($buildNumber.Contains('-'))
    {
        $buildNumber = "unreleased"
    }
    else
    {
        $buildNumber = $buildNumber.Substring(0, $buildNumber.LastIndexOf('.'))
    }

    #Write-Host "Source Build:" $buildNumber

    $text = Get-Content $changeLog

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

function UpdateChangelog($fileName, $entryType, $code, $message) {
# todo
} 