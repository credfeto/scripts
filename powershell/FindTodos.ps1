param(
    [string] $solutionDirectory = $(throw "Directory containing projects")
)

Set-StrictMode -Version 1
$InformationPreference = "Continue"


function InTeamCity {
    $version = [System.Environment]::GetEnvironmentVariable('TEAMCITY_VERSION')
    #$version = Get-ChildItem -Path Env:\TEAMCITY_VERSION
    ## For testing service messages locally
    #$version = Get-ChildItem -Path Env:\PROCESSOR_LEVEL
    if($version) {
        return $true
    }
    
    return $false
}

function WriteProgress {
param([string]$message)
    $tc = InTeamCity 
    if($tc) {
        Write-Information "##teamcity[progressMessage '$message']"
    }
    else {
        Write-Information $message
    }
}

function WriteSectionStart {
param([string]$message)
    $tc = InTeamCity 
    if($tc) {
        Write-Information "##teamcity[progressStart '$message']"
    }
    else {
        Write-Information ""
        Write-Information $message
    }
}

function WriteSectionEnd {
param([string]$message)
    $tc = InTeamCity 
    if($tc) {
        Write-Information "##teamcity[progressFinish '$message']"
    }
    else {
        # Don't log anything for end section
    }
}
function WriteStatistics {
param(
    [string]$Section,
    $Value)
   $tc = InTeamCity 
   if($tc) {
       Write-Information "##teamcity[buildStatisticValue key='$section' value='$value']"
   }
}

function CheckTodos {
    param(
        [string]$sourceDirectory = $(throw "Directory containing projects")
    )
    
    $files = Get-ChildItem -Path $sourceDirectory -Filter "*.cs" -Recurse
    [int]$progress = 0
    [int]$issues = 0
    [int]$todos = 0
    [int]$resharper = 0
    [int]$supppresions = 0
    [int]$errors = 0
    [int]$totalFiles = $files.Count

    [string]$regexResharper = "//\s+ReSharper\s+disable\s+once\s+"
    [string]$regexTodo = "(?i://\s+TODO\s+)"
    [string]$regexSuppressTodo = "\[SuppressMessage\((category:)?\s+""(.*)?"",\s+(checkId:\s+)?""(.*)?"",\s+Justification\s+=\s+""TODO:(.*)?""\)\]"
    Write-Information $regexSuppressTodo

    
    ForEach($file in $files) {
        [string]$fileName = $file.FullName
        [string]$relativeFileName = $fileName.Substring($sourceDirectory.Length)

        ++$progress
        [bool]$found = false

        # Simple line by line version  - really should be using a regex that works across multiple lines
        $file = Get-Content $fileName
        [int]$lineIndex = 0;
        [int]$issuesAtFileStart = $issues
        foreach($line in $file) {
            ++$lineIndex
            $trimLine = $line.Trim()
            
            # Check for ReSharper disable once
            if($trimLine -match $regexResharper) {                
                ++$issues
                ++$resharper
                ++$errors
                if(!$found) {
                    WriteSectionStart -Message "($progress/$totalFiles) Checking $relativeFileName"
                    $found = true
                }

                WriteProgress "${lineIndex}: $trimLine"
                
                $found = $true
                
                Continue
            }
            
            # Check for ReSharper disable once
            if($trimLine -match $regexSuppressTodo) {                
                ++$issues
                ++$supppresions
                ++$errors
                if(!$found) {
                    WriteSectionStart -Message "($progress/$totalFiles) Checking $relativeFileName"
                    $found = true
                    
                }

                WriteProgress "${lineIndex}: $trimLine"
                
                $found = $true
                Continue
            }
            
            # Check for simple TODO comment
            if($trimLine -match $regexTodo) {                
                ++$issues
                ++$todos
                if(!$found) {
                    WriteSectionStart -Message "($progress/$totalFiles) Checking $relativeFileName"
                    $found = true
                }

                WriteProgress "${lineIndex}: $trimLine"
                
                $found = $true
                Continue
            }
        }
                        
        if($found) {
            $totalIssues = $issues - $issuesAtFileStart
            WriteSectionEnd -Message "($progress/$totalFiles) Checking $relativeFileName"
        }
    }
    
    WriteStatistics "TODO" $todos
    WriteStatistics "ResharperSuppression" $resharper
    WriteStatistics "Issues" $issues
    
    return $errors
}


#########################################################################
#########################################################################
#########################################################################
#########################################################################


if(!$solutionDirectory.EndsWith("\")) {
    $solutionDirectory = $solutionDirectory + "\"
}

$result = CheckTodos -sourceDirectory $solutionDirectory

Exit $result
