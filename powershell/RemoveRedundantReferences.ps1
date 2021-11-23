
#########################################################################
# https://devblog.pekspro.com/posts/finding-redundant-project-references
#########################################################################

param(
    [string] $solutionDirectory = $(throw "Directory containing projects")
)

$InformationPreference = "Continue"

function ExtractProjectFromReference {
    param([string]$reference)

    $last = $reference.LastIndexOf("\")
    if($last -gt -1) {
        $last = $last + 1

        $res = $reference.SubString($last, $reference.Length - $last)

        if($res.EndsWith(".csproj")) {
            $res = $res.Substring(0, $res.Length - 7)
            return $res
        }
    }

    return $null
}

function IsDoNotRemovePackage {
    param($PackageId)

    if($PackageId -eq "FunFair.Test.Common") {
        return $true
    }
    
    if($PackageId -eq "Microsoft.NET.Test.Sdk") {
        return $true
    }

    if($PackageId -eq "NSubstitute") {
        return $true
    }

    if($PackageId -eq "TeamCity.VSTest.TestAdapter") {
        return $true
    }

    if($PackageId -eq "xunit") {
        return $true
    }

    if($PackageId -eq "xunit.runner.visualstudio") {
        return $true
    }

    if($PackageId -eq "Secp256k1.Native") {
        # Referenced but not in an obvious way
        return $true
    }
    
    if($PackageId -eq "Castle.Core") {
        # Has bug fix
        return $true
    }

    if($PackageId.StartsWith("LibSassHost.Native.")) {
        # Referenced but not in an obvious way
        return $true
    }

    return $false
}


function Get-PackageReferences {
    param($FileName, $IncludeReferences, $IncludeChildReferences)

    $xml = [xml] (Get-Content $FileName)

    $references = @()

    if($IncludeReferences) {
        $packageReferences = $xml | Select-Xml -XPath "Project/ItemGroup/PackageReference"

        foreach($node in $packageReferences)
        {
            if($node.Node.Include)
            {
                if($node.Node.PrivateAssets)
                {
                    continue
                }

                $doNotRemove = IsDoNotRemovePackage -PackageId $node.Node.Include
                if($doNotRemove)
                {
                    continue
                }

                if($node.Node.Version)
                {
                    $references += [PSCustomObject]@{
                        File = (Split-Path $FileName -Leaf);
                        Name = $node.Node.Include;
                        Version = $node.Node.Version;
                    }
                }
            }
        }
    }

    if($IncludeChildReferences)
    {
        $projectReferences = $xml | Select-Xml -XPath "Project/ItemGroup/ProjectReference"

        foreach($node in $projectReferences)
        {
            if($node.Node.Include)
            {
                $childPath = Join-Path -Path (Split-Path $FileName -Parent) -ChildPath $node.Node.Include

                $childPackageReferences = Get-PackageReferences $childPath $true $true

                $references += $childPackageReferences
            }
        }
    }

    return $references
}

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

function TeamCityProgress {
param([string]$message)
    $tc = InTeamCity 
    if($tc) {
        Write-Information "##teamcity[progressMessage '$message']"
    }
}

function TeamCityProgressStart {
param([string]$message)
    $tc = InTeamCity 
    if($tc) {
        Write-Information "##teamcity[progressStart '$message']"
    }
}

function TeamCityProgressEnd {
param([string]$message)
    $tc = InTeamCity 
    if($tc) {
        Write-Information "##teamcity[progressStart '$message']"
    }
}
function TeamCityStatistics {
param(
    [string]$Section,
    $Value)
   $tc = InTeamCity 
   if($tc) {
       Write-Information "##teamcity[buildStatisticValue key='$section' value='$value']"
   }
}

function BuildProject {
    param([string]$FileName, [bool]$FullError)

    $errorCode = "AD0001"
    $NewLine = [System.Environment]::NewLine
    do
    {
        $results = dotnet build $file.FullName -warnAsError -nodeReuse:False /p:SolutionDir=$solutionDirectory
        if(!$?) {
            $resultsAsText = $results -join $NewLine
            #Write-Information "**** FAILED ****"
            $retry = $resultsAsText.Contains($errorCode) 
            if(!$retry)
            {
                if($FullError)
                {
                    Write-Error $resultsAsText
                }
                return $false
            }
        }
        else {
            #Write-Information "**** SUCCESS ****" 
            return $true
        }
    }
    while($true)
}

function Get-ProjectReferences {
    param($FileName, $IncludeReferences, $IncludeChildReferences)

    $xml = [xml] (Get-Content $FileName)

    $references = @()

    if($IncludeReferences) {
        $projectReferences = $xml | Select-Xml -XPath "Project/ItemGroup/ProjectReference"

        foreach($node in $projectReferences)
        {
            if($node.Node.Include)
            {
                $references += [PSCustomObject]@{
                    File = (Split-Path $FileName -Leaf);
                    Name = $node.Node.Include;
                }
            }
        }
    }

    if($IncludeChildReferences)
    {
        $projectReferences = $xml | Select-Xml -XPath "Project/ItemGroup/ProjectReference"

        foreach($node in $projectReferences)
        {
            if($node.Node.Include)
            {
                $childPath = Join-Path -Path (Split-Path $FileName -Parent) -ChildPath $node.Node.Include

                $childProjectReferences = Get-ProjectReferences $childPath $true $true

                $references += $childProjectReferences
            }
        }
    }

    return $references
}

function ShouldHaveNarrowerPackageReference {
    param([string]$ProjectFolder, [string]$PackageId)

    if(!$PackageId.StartsWith("FunFair.")) {
        # not a package we control
        return $false
    }
    
    if($PackageId.EndsWith(".All")){
        # This is explicitly a grouping package
        return $false
    }

    $sourceFiles = Get-ChildItem -Path $ProjectFolder -Filter *.cs -Recurse
    
    $search = "using $PackageId"
    #Write-Information "Looking for $search"
    foreach($file in $sourceFiles) {
        #Write-Information $file.FullName
        $content = Get-Content $file.FullName -Raw
        
        if($content.Contains($search))
        {
            return $false
        }
    }
    
    Write-Information "  - Did not Find $PackageId source reference in project"
    
    return $true
}

function CheckReferences {
param(
    [string]$sourceDirectory
)
    $files = Get-ChildItem -Path $sourceDirectory -Filter *.csproj -Recurse
    
    
    Write-Information "Number of projects: $($files.Length)"
    
    $stopWatch = [System.Diagnostics.Stopwatch]::startNew()
    
    $obseletes = @()
    $reduceReferences = @()
    $changeSdk = @()
    
    $projectCount = $files.Length
    $projectInstance = 0
    $minimalSdk = "Microsoft.NET.Sdk"
    
    foreach($file in $files) {
    
        $projectInstance = $projectInstance + 1
        
        Write-Information ""
        Write-Information "($projectInstance/$projectCount): Testing project: $($file.Name)"
        TeamCityProgressStart "($projectInstance/$projectCount): Testing project: $($file.Name)"
    
        $rawFileContent = [System.IO.File]::ReadAllBytes($file.FullName)
    
        $buildOk = BuildProject -FileName $file.FullName -FullError $true
        if(!$buildOk) {
            Write-Information "* Does not build without changes"
            throw "Failed to build a project"
        }
        
        $childPackageReferences = Get-PackageReferences $file.FullName $false $true
        $childProjectReferences = Get-ProjectReferences $file.FullName $false $true
    
        $xml = [xml] (Get-Content $file.FullName)
        
        $projectXml = $xml | Select-Xml -XPath "Project"
        
        if($projectXml)
        {
            TeamCityProgress "SDK"
            $sdk = $projectXml[0].Node.Sdk            
            if($sdk.StartsWith("Microsoft.NET.Sdk.")) {
                $projectXml[0].Node.Sdk = $minimalSdk
                $xml.Save($file.FullName)
                
                Write-Information "* Building $( $file.Name ) using $minimalSdk instead of $sdk..."
                $buildOk = BuildProject -FileName $file.FullName -FullError $false
                if($buildOk) {
                    Write-Information "  - Building succeeded."
                    Write-Information "$( $file.Name ) references SDK $sdk that could be reduced to $minimalSdk."
                    $changeSdk += [PSCustomObject]@{
                                                   File = $file;
                                                   Type = 'Sdk';
                                                   Name = $sdk;                                               
                                               }
                }
                else {
                    Write-Information "  = Building failed."
                }
                
                $projectXml[0].Node.Sdk = $sdk
                $xml.Save($file.FullName)
            } else {
                Write-Information "= SDK does not need changing. Currently $minimalSdk."
            }                   
        }
         
    
        $packageReferences = $xml | Select-Xml -XPath "Project/ItemGroup/PackageReference"
        $projectReferences = $xml | Select-Xml -XPath "Project/ItemGroup/ProjectReference"
    
        $nodes = @($packageReferences) + @($projectReferences)
    
        foreach($node in $nodes) {
            if($node.Node.Include)
            {
                $doNotRemove = IsDoNotRemovePackage -PackageId $node.Node.Include
                if($doNotRemove)
                {
                    Write-Host "= Skipping $( $node.Node.Include ) as it is marked as do not remove"
                    continue
                }
            }
            else {
                Write-Host "= Skipping malformed include"
                continue
            }
            
            if($node.Node.PrivateAssets)
            {
                Write-Host "= Skipping $( $node.Node.Include ) as it uses private assets"
                continue
            }
            
            TeamCityProgress $node.Node.Include
    
    
            $previousNode = $node.Node.PreviousSibling
            $parentNode = $node.Node.ParentNode
            $parentNode.RemoveChild($node.Node) > $null
            
            $needToBuild = $true
            
            $xml.Save($file.FullName)
    
            if($node.Node.Version)
            {
                $existingChildInclude = $childPackageReferences | Where-Object { $_.Name -eq $node.Node.Include -and $_.Version -eq $node.Node.Version } | Select-Object -First 1
    
                if ($existingChildInclude)
                {
                    Write-Information "= $( $file.Name ) references package $( $node.Node.Include ) ($( $node.Node.Version )) that is also referenced in child project $( $existingChildInclude.File )."
                    $needToBuild = $false
                }
                else
                {
                    Write-Information "* Building $( $file.Name ) without package $( $node.Node.Include ) ($( $node.Node.Version ))... "
                }
            }
            else
            {
                $existingChildInclude = $childProjectReferences | Where-Object { $_.Name -eq $node.Node.Include } | Select-Object -First 1
    
                if($existingChildInclude)
                {
                    Write-Information "= $($file.Name) references project $($node.Node.Include) that is also referenced in child project $($existingChildInclude.File)."
                    $needToBuild = $false
                }
                else
                {
                    Write-Information "* Building $($file.Name) without project $($node.Node.Include)... "
                }
            }
            
            if($needToBuild) {
                $buildOk = BuildProject -FileName $file.FullName -FullError $false    
            }
            else
            {
                $buildOk = $true
            }
            
            if($buildOk)
            {
                Write-Information "  - Building succeeded."
    
                if($node.Node.Version)
                {
                    $obseletes += [PSCustomObject]@{
                        File = $file;
                        Type = 'Package';
                        Name = $node.Node.Include;
                        Version = $node.Node.Version;
                    }
                }
                else
                {
                    $obseletes += [PSCustomObject]@{
                        File = $file;
                        Type = 'Project';
                        Name = $node.Node.Include;
                    }
                }
            }
            else
            {
                Write-Information "  = Building failed."
                if($node.Node.Version)
                {
                    $narrower = ShouldHaveNarrowerPackageReference -ProjectFolder $file.Directory.FullName -PackageId $node.Node.Include
                    if($narrower)
                    {
                        $reduceReferences += [PSCustomObject]@{
                            File = $file;
                            Type = 'Package';
                            Name = $node.Node.Include;
                            Version = $node.Node.Version;
                        }
                    } 
                }
                else {
                    $packageId = ExtractProjectFromReference -reference $node.Node.Include
                    if($packageId)
                    {
                        $narrower = ShouldHaveNarrowerPackageReference -ProjectFolder $file.Directory.FullName -PackageId $packageId
                        if ($narrower)
                        {
                            $reduceReferences += [PSCustomObject]@{
                                File = $file;
                                Type = 'Project';
                                Name = $node.Node.Include;
                                Version = $node.Node.Version;
                            }
                        }
                    }
                }
            }
    
    
            if($null -eq $previousNode)
            {
                $parentNode.PrependChild($node.Node) > $null
            }
            else
            {
                $parentNode.InsertAfter($node.Node, $previousNode.Node) > $null
            }
    
            # $xml.OuterXml
    
            $xml.Save($file.FullName)
        }
    
        [System.IO.File]::WriteAllBytes($file.FullName, $rawFileContent)
    
        $buildOk = BuildProject -FileName $file.FullName -FullError $true
        if(!$buildOk)
        {
            Write-Error "### Failed to build $($file.FullName) after project file restore. Project build successfully before ###"
            throw "Failed to build project after restore"
        }
        
        TeamCityProgressEnd "($projectInstance/$projectCount): Testing project: $($file.Name)"
    }
    
    Write-Information ""
    Write-Information "-------------------------------------------------------------------------"
    Write-Information "Analyse completed in $($stopWatch.Elapsed.TotalSeconds) seconds"
    Write-Information "$($changeSdk.Length) SDK reference(s) could potentially be narrowed."
    Write-Information "$($obseletes.Length) reference(s) could potentially be removed."
    Write-Information "$($reduceReferences.Length) reference(s) could potentially be switched to different packages."
    
    TeamCityStatistics -Section "SDK" -Value $changeSdk.Length
    TeamCityStatistics -Section "Obsolete" -Value $obseletes.Length
    TeamCityStatistics -Section "Reduce" -Value $reduceReferences.Length
    
    Write-Information "SDK:"
    $previousFile = $null
    foreach($sdkRef in $changeSdk)
    {
        if($previousFile -ne $sdkRef.File)
        {
            Write-Information ""
            Write-Information "Project: $($sdkRef.File.Name)"
        }
    
        Write-Information "* Project reference: $($sdkRef.Name)"
    
        $previousFile = $sdkRef.File
    }
    
    
    Write-Information "Obsolete:"
    $previousFile = $null
    foreach($obselete in $obseletes)
    {
        if($previousFile -ne $obselete.File)
        {
            Write-Information ""
            Write-Information "Project: $($obselete.File.Name)"
        }
    
        if($obselete.Type -eq 'Package')
        {
            Write-Information "* Package reference: $($obselete.Name) ($($obselete.Version))"
        }
        else
        {
            Write-Information "* Project reference: $($obselete.Name)"
        }
    
        $previousFile = $obselete.File
    }
    
    Write-Information ""
    Write-Information "Reduce Scope:"
    $previousFile = $null
    foreach($reduce in $reduceReferences)
    {
        if($previousFile -ne $reduce.File)
        {
            Write-Information ""
            Write-Information "Project: $($reduce.File.Name)"
        }
    
        if($reduce.Type -eq 'Package')
        {
            Write-Information "* Package reference: $($reduce.Name) ($($reduce.Version))"
        }
        else
        {
            Write-Information "* Project reference: $($reduce.Name)"
        }
    
        $previousFile = $reduce.File
    }
    
    # No obsoletes and no SDK changes then exit code = 0 = Success
    $totalOptimisations = $obseletes.Length + $changeSdk.Length + $reduceReferences.Length
    return $totalOptimisations
}


if(!$solutionDirectory.EndsWith("\")) {
    $solutionDirectory = $solutionDirectory + "\"
}

$result = CheckReferences -sourceDirectory $solutionDirectory

Exit $result