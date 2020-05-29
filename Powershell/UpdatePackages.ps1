#########################################################################

param(
    [string] $repos = $(throw "repos.lst file containing list of repositories"),
    [string] $packagesToUpdate = $(throw "Packages.json file to load")
)

Remove-Module *

$ErrorActionPreference = "Stop" 
$packageIdToInstall = "Credfeto.Package.Update"
$preRelease = $False
$root = Get-Location
Write-Host $root


#########################################################################

# region Include required files
#
$ScriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
$ScriptDirectory = Join-Path -Path $ScriptDirectory -ChildPath "Lib" 
try {
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "DotNetTool.psm1") -Force -DisableNameChecking
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "GitUtils.psm1") -Force -DisableNameChecking
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "DotNetBuild.psm1") -Force -DisableNameChecking
    Import-Module (Join-Path -Path $ScriptDirectory -ChildPath "Changelog.psm1") -Force -DisableNameChecking
}
catch {
    Throw "Error while loading supporting PowerShell Scripts" 
}
#endregion


function checkForUpdates($repoFolder, $packageId) {

    $results = dotnet updatepackages -folder $repoFolder -prefix $packageId 

    if($?) {
        
        # has updates
        $packageIdAsRegex = $packageId.Replace(".", "\.").ToLower()
        $regexPattern = "echo ::set-env name=$packageIdAsRegex::(?<Version>\d+(\.\d+)+)"

        $regex = new-object System.Text.RegularExpressions.Regex($regexPattern, [System.Text.RegularExpressions.RegexOptions]::MultiLine)
        $matches = $regex.Matches($results.ToLower());
        if($matches.Count -gt 0) {
            $version = $matches[0].Groups["Version"].Value
            Write-Host "Found: $version"
            return $version
        }
    }
    

    Write-Host " * No Changes"    
    return $null
}

function processRepo($repo, $packages) {
    
    Set-Location $root
    
    Write-Host ""
    Write-Host "***********************************************************************************"
    Write-Host "***********************************************************************************"
    Write-Host "***********************************************************************************"
    Write-Host "***********************************************************************************"
    Write-Host ""
    Write-Host "Processing Repo: $repo"

    # Extract the folder from the repo name
    $folder = $repo.Substring($repo.LastIndexOf("/")+1)
    $folder = $folder.SubString(0, $folder.LastIndexOf("."))

    Write-Host "Folder: $folder"
    $repoFolder = Join-Path -Path $root -ChildPath $folder

    Git-EnsureSynchronised -repo $repo -repofolder $repoFolder

    $srcPath = Join-Path -Path $repoFolder -ChildPath "src"
    $srcExists = Test-Path -Path $srcPath
    if($srcExists -eq $false) {
        # no source to update
        Write-Host "* No src folder in repo"
        return;
    }

    $projects = Get-ChildItem -Path $srcPath -Filter *.csproj -Recurse
    if($projects.Length -eq 0) {
        # no source to update
        Write-Host "* No C# projects in repo"
        return;
    }


    $changeLog = Join-Path -Path $repoFolder -ChildPath "CHANGELOG.md"

    $codeOK = DotNet-BuildSolution -srcFolder $srcPath
    if($codeOk -eq $false) {
        # no point updating
        Write-Host "* WARNING: Solution doesn't build without any changes - no point in trying to update packages"
        return;
    }

    ForEach($package in $packages) {
        $packageId = $package.packageId
        $type = $package.type

        Write-Host ""
        Write-Host "------------------------------------------------"
        Write-Host "Looking for updates of $packageId"
        $update = checkForUpdates -repoFolder $repoFolder -packageId $package.packageId
        if($update -eq $null) {
            Continue
        }

        $branchName = "depends/ff-1429-update-$packageId/$update"
        $branchExists = Git-DoesBranchExist -branchName $branchName
        if($branchExists -ne $true) {

            Write-Host ">>>> Checking to see if code builds against $packageId $update <<<<"
            $codeOK = DotNet-BuildSolution -baseFolder $repoFolder
            if($codeOK -eq $true) {
                ChangeLog-AddEntry -fileName $changeLog -entryType "Changed" -code "FF-1429" -message "Updated $packageId to $update"
                Git-Commit -message "[FF-1429] Updating $packageId ($type) to $update"
                Git-Push
            }
            else {
                Write-Host "Create Branch $branchName"
                $branchOk = Git-CreateBranch -name $branchName
                if($branchOk -eq $true) {
                    ChangeLog-AddEntry -fileName $changeLog -entryType "Changed" -code "FF-1429" -message "Updated $packageId to $update"
                    Git-Commit -message "[FF-1429] Updating $packageId ($type) to $update"
                    Git-PushOrigin -branchName $branchName
                } else {
                    Write-Host ">>> ERROR: FAILED TO CREATE BRANCH <<<"
                }
            }
        }
        else {
                Write-Host "Branch $branchName already exists - skipping"
        }
 
        Git-ResetToMaster        
    }
}

#########################################################################


$installed = DotNetTool-Install -packageId $packageIdToInstall -preReleaseVersion $preRelease

if($installed -eq $false) {
    Write-Error ""
	Write-Error "#teamcity[buildStatus status='FAILURE' text='Failed to install $packageIdToInstall']"
}


$packages = Get-Content $packagesToUpdate| Out-String | ConvertFrom-Json

$repoList = Git-LoadRepoList -repos $repos
ForEach($repo in $repoList) {
    if($repo.Trim() -eq "") {
        continue
    }

    processRepo -repo $repo -packages $packages
}

Set-Location $root

Write-Host ">>>>>>>>>>>> ALL REPOS PROCESSED <<<<<<<<<<<<"





#$repos | ConvertFrom-Json

