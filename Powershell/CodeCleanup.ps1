#########################################################################

param(
    [string] $repos = $(throw "repos.lst file containing list of repositories")
)

Remove-Module *

$InformationPreference = "Continue"
$ErrorActionPreference = "Stop" 
$packageIdToInstall = "JetBrains.ReSharper.GlobalTools"
$preRelease = $False
$root = Get-Location
Write-Information $root


#########################################################################

# region Include required files
#
$ScriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
$ScriptDirectory = Join-Path -Path $ScriptDirectory -ChildPath "Lib" 
Write-Information "Loading Modules from $ScriptDirectory"
try {
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "DotNetTool.psm1") -Force -DisableNameChecking
}
catch {
    Write-Error $Error[0]
    Throw "Error while loading supporting PowerShell Scripts: DotNetTool" 
}

try
{
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "GitUtils.psm1") -Force -DisableNameChecking
}
catch {
    Write-Error $Error[0]
    Throw "Error while loading supporting PowerShell Scripts: GitUtils" 
}

try
{
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "DotNetBuild.psm1") -Force -DisableNameChecking
}
catch {
    Write-Error $Error[0]
    Throw "Error while loading supporting PowerShell Scripts: DotNetBuild" 
}
#endregion



function runCodeCleanup($solutionFile) {

    $tempFolder = [System.IO.Path]::GetTempPath()

    $sourceFolder = Split-Path -Path $solutionFile -Parent
    $sourceFolderWithoutDrive = $sourceFolder
    if($sourceFolder[1] -eq ":") { 
        $sourceFolderWithoutDrive = $sourceFolder.Substring(3)
    }    

    $cachesFolder = Join-Path -Path $tempFolder -ChildPath $sourceFolderWithoutDrive
    $settingsFile = $solutionFile + ".DotSettings"

    $buildOk = DotNet-BuildSolution -srcFolder $sourceFolder
    if($buildOk -eq $true) {

        Write-Information "* Changing Resharper disable once comments to SuppressMessage"
        Write-Information "  - Folder: $sourceFolder"

        $singleBlankLine = "(\r|\n|\r\n|\n\r)"
        $linesToRemoveRegex = "(?<LinesToRemove>((\r+)|(\n+)|((\r\n)+)|(\n\r)+))"
        $suppressMessageRegex = "(?<End>\s+\[(System\.Diagnostics\.CodeAnalysis\.)?SuppressMessage)"
        $removeBlankLinesRegex = "(?ms)" +  "(?<Start>(^((\s+)///\s+</(.*?)\>"+ $singleBlankLine +")))" + $linesToRemoveRegex + $suppressMessageRegex
        $removeBlankLines2Regex = "(?ms)" + "(?<Start>(^((\s+)///\s+<(.*?)/\>"+ $singleBlankLine +")))" + $linesToRemoveRegex + $suppressMessageRegex

        $replacements = "RedundantDefaultMemberInitializer",
                        "ParameterOnlyUsedForPreconditionCheck.Global",
                        "ParameterOnlyUsedForPreconditionCheck.Local",
                        "UnusedMember.Global",
                        "UnusedMember.Local",        
                        "AutoPropertyCanBeMadeGetOnly.Global",
                        "AutoPropertyCanBeMadeGetOnly.Local",
                        "ClassNeverInstantiated.Local",
                        "ClassNeverInstantiated.Global",
                        "ClassCanBeSealed.Global",
                        "ClassCanBeSealed.Local",
                        "UnusedAutoPropertyAccessor.Local",
                        "UnusedAutoPropertyAccessor.Global",       
                        "InconsistentNaming",
                        "IdentifierTypo"

        $files = Get-ChildItem -Path $srcPath -Filter "*.cs" -Recurse
        ForEach($file in $files) {
            $fileName = $file.FullName

            $content = Get-Content -Path $fileName -Raw
            $originalContent = $content
            $updatedContent = $content

            $changedFile = $False

            ForEach($replacement in $replacements) {
                $code = $replacement.Replace(".", "\.")
                $regex = "//\s+ReSharper\s+disable\s+once\s+$code"
                $replacementText = "[System.Diagnostics.CodeAnalysis.SuppressMessage(""ReSharper"", ""$replacement"", Justification=""TODO: Review"")]"

                $updatedContent = $content -replace $regex, $replacementText
                if($content -ne $updatedContent)
                {
                    $content = $updatedContent
                    if($changedFile -eq $False) {
                        Write-Information "* $fileName"
                        $changedFile = $True
                    }

                    Write-Information "   - Changed $replacement comment to SuppressMessage"                    
                }
            }

            $updatedContent = $content -replace $removeBlankLinesRegex, '${Start}${End}'
            if($content -ne $updatedContent)
            {
                $content = $updatedContent
                if($changedFile -eq $False) {
                    Write-Information "* $fileName"
                    $changedFile = $True
                }

                Write-Information "   - Removed blank lines (end tag)"
            }


            $updatedContent = $content -replace $removeBlankLines2Regex, '${Start}${End}'
            if($content -ne $updatedContent)
            {
                $content = $updatedContent
                if($changedFile -eq $False) {
                    Write-Information "* $fileName"
                    $changedFile = $True
                }

                Write-Information "   - Removed blank lines (single tag)"
            }

            if($content -ne $originalContent) {
                Set-Content -Path $fileName -Value $content
            }
        }

        Write-Information "* Running Code Cleanup"
        Write-Information "  - Solution: $Solution"
        Write-Information "  - Cache Folder: $cachesFolder"
        Write-Information "  - Settings File: $settingsFile"
        dotnet jb cleanupcode --profile="Full Cleanup" $solutionFile --properties:Configuration=Release --caches-home:"$cachesFolder" --settings:"$settingsFile" --verbosity:INFO --no-buildin-settings
        if(!$?) {
            Write-Information ">>>>> Code Cleanup failed"
            return $false
        }

        Write-Information "* Building after cleanup"
        $result = DotNet-BuildSolution -srcFolder $sourceFolder
        if($result -eq $true) {
            return $true
        }

	Write-Information ">>>>> Build Failed!"
	exit
    }

    Write-Information ">>>>> Build Failed!"
    return $false
}


function processRepo($srcRepo, $repo) {
    
    Write-Information ""
    Write-Information "***************************************************************"
    Write-Information "***************************************************************"
    Write-Information ""

    Set-Location -Path $root
    
    Write-Information "Processing Repo: $repo"

    # Extract the folder from the repo name
    $folder = Git-GetFolderForRepo -repo $repo

    Write-Information "Folder: $folder"
    $repoFolder = Join-Path -Path $root -ChildPath $folder

    Git-EnsureSynchronised -repo $repo -repofolder $repoFolder

    Set-Location -Path $repoFolder

    #########################################################
    # C# file updates
    $srcPath = Join-Path -Path $repoFolder -ChildPath "src"
    $srcExists = Test-Path -Path $srcPath
    if($srcExists -eq $true) {
        
        $solutions = Get-ChildItem -Path $srcPath -Filter "*.sln"
        foreach($solution in $solutions) {

            $solutionFile = $solution.FullName
            $solutionName = $solution.Name
            $branchName = "cleanup/ff-2244/$solutionName"
            $branchExists = Git-DoesBranchExist -branchName $branchName
            if($branchExists -ne $true) {

                $cleaned = runCodeCleanup -solutionFile $solution.FullName
                if($cleaned -eq $true) {

                    Set-Location -Path $repoFolder

                    $hasChanges = Git-HasUnCommittedChanges
                    if($hasChanges -eq $true) {
                        Git-CreateBranch -branchName $branchName
                        Git-Commit -message "[FF-2244] - Code cleanup on $solutionName"
                        Git-PushOrigin -branchName $branchName
                    }
                }

                Git-ResetToMaster
            }
        }    
    }
}



#########################################################################


$installed = DotNetTool-Install -packageId $packageIdToInstall -preReleaseVersion $preRelease

if($installed -eq $false) {
    Write-Error ""
	Write-Error "#teamcity[buildStatus status='FAILURE' text='Failed to install $packageIdToInstall']"
}


[string[]] $repoList = Git-LoadRepoList -repoFile $repos

Write-Information ""
Write-Information "***************************************************************"
Write-Information "***************************************************************"
Write-Information ""

Set-Location -Path $root   

ForEach($repo in $repoList) {
    if($repo.Trim() -eq "") {
        continue
    }

    processRepo -srcRepo $templateRepoFolder -repo $repo
}

Set-Location -Path $root

