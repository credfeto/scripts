
#########################################################################
# Based on code at
# https://devblog.pekspro.com/posts/finding-redundant-project-references
#########################################################################

param(
    [string] $solutionDirectory = $(throw "Directory containing projects")
)

Set-StrictMode -Version 1
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
    param([string]$PackageId,
        [string[]]$allPackageIds
    )

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

    if($PackageId -eq "System.IdentityModel.Tokens.Jwt") {         
        if($allPackageIds -contains "Microsoft.AspNetCore.Authentication.JwtBearer") {
            return $true
        }

        if($allPackageIds -contains "Microsoft.IdentityModel.Tokens") {
            return $true
        }

        return $false
    }

    if($PackageId -eq "Microsoft.AspNetCore.Authentication.JwtBearer") {         
        if($allPackageIds -contains "Microsoft.IdentityModel.Tokens") {
            return $true
        }

        if($allPackageIds -contains "Microsoft.AspNetCore.Authentication.JwtBearer") {
            return $true
        }

        return $false
    }

    if($PackageId -eq "Microsoft.IdentityModel.Tokens") {         
        if($allPackageIds -contains "System.IdentityModel.Tokens.Jwt") {
            return $true
        }

        if($allPackageIds -contains "Microsoft.AspNetCore.Authentication.JwtBearer") {
            return $true
        }

        return $false
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

    [string[]]$allPackageIds = @()
    $references = @()

    if($IncludeReferences) {
        $packageReferences = $xml | Select-Xml -XPath "Project/ItemGroup/PackageReference"

        foreach($node in $packageReferences)
        {
            if($node.Node.Include)
            {
                $packageId = $node.Node.Include
                $allPackageIds += $packageId
            }
        }
        
        foreach($node in $packageReferences)
        {
            if($node.Node.Include)
            {
                if($node.Node.PrivateAssets)
                {
                    continue
                }

                $doNotRemove = IsDoNotRemovePackage -PackageId $node.Node.Include -allPackageIds $allPackageIds
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
        Write-Information $message
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

function BuildProject {
    param([string]$FileName, [bool]$FullError)

    $errorCode = "AD0001"
    $NewLine = [System.Environment]::NewLine
    do
    {
        $results = dotnet build $file.FullName -warnAsError -nodeReuse:False /p:SolutionDir=$solutionDirectory
        if(!$?) {
            $resultsAsText = $results -join $NewLine
            #WriteProgress "**** FAILED ****"
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
            #WriteProgress "**** SUCCESS ****" 
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
    
    $searchUsing = "using $PackageId"
    $searchNamespace = "namespace $PackageId."
    #WriteProgress "Looking for $search"
    foreach($file in $sourceFiles) {
        #WriteProgress $file.FullName
        $content = Get-Content $file.FullName -Raw
        
        if($content.Contains($searchUsing)) {
            return $false
        }
        
        if($content.Contains($searchNamespace)) {
            return $false
        }
    }
    
    WriteProgress "  - Did not Find $PackageId source reference in project"
    
    return $true
}

function ShouldCheckSdk {
param(
    [string]$sdk,
    [string]$projectFolder,
    [xml] $xml
)
    if(!$sdk.StartsWith("Microsoft.NET.Sdk.")) {
        return $false
    }
    
    if($sdk -eq "Microsoft.NET.Sdk.Razor") {
        $cshtmlFiles = Get-ChildItem -Path $projectFolder -Filter *.cshtml -Recurse
        if($cshtmlFiles.Length -eq 0) {
            return $true
        }
        
        return $false
    }
    
    if($sdk -eq "Microsoft.NET.Sdk.Web") {
        $outputType = $xml | Select-Xml -XPath "/Project/PropertyGroup/OutputType"
        if($outputType) {   
            if($outputType[0].Node.InnerText -eq "Exe") {
                # Assume Exes are of the right type
                return $false
            }
        }
    }
    
    return $true
}

function CheckReferences {
param(
    [string]$sourceDirectory
)
    $files = Get-ChildItem -Path $sourceDirectory -Filter *.csproj -Recurse
    
    
    WriteProgress "Number of projects: $($files.Length)"
    
    WriteSectionStart "Checking Projects"
    
    $stopWatch = [System.Diagnostics.Stopwatch]::startNew()
    
    $obsoletes = @()
    $reduceReferences = @()
    $changeSdk = @()
    
    $projectCount = $files.Length
    $projectInstance = 0
    $minimalSdk = "Microsoft.NET.Sdk"
    
    foreach($file in $files) {
    
        $projectInstance = $projectInstance + 1
        
        WriteSectionStart "($projectInstance/$projectCount): Testing project: $($file.Name)"
    
        $rawFileContent = [System.IO.File]::ReadAllBytes($file.FullName)
    
        $buildOk = BuildProject -FileName $file.FullName -FullError $true
        if(!$buildOk) {
            WriteProgress "* Does not build without changes"
            throw "Failed to build a project"
        }
        
        $childPackageReferences = Get-PackageReferences $file.FullName $false $true
        $childProjectReferences = Get-ProjectReferences $file.FullName $false $true
    
        $xml = [xml] (Get-Content $file.FullName)
        
        $projectXml = $xml | Select-Xml -XPath "Project"
        
        if($projectXml)
        {
            WriteProgress "SDK"
            $sdk = $projectXml[0].Node.Sdk
            $shouldReplaceSdk = ShouldCheckSdk -Sdk $sdk -projectFolder $file.Directory.FullName -xml $xml            
            if($shouldReplaceSdk) {
                $projectXml[0].Node.Sdk = $minimalSdk
                $xml.Save($file.FullName)
                
                WriteProgress "* Building $( $file.Name ) using $minimalSdk instead of $sdk..."
                $buildOk = BuildProject -FileName $file.FullName -FullError $false
                if($buildOk) {
                    WriteProgress "  - Building succeeded."
                    WriteProgress "$( $file.Name ) references SDK $sdk that could be reduced to $minimalSdk."
                    $changeSdk += [PSCustomObject]@{
                                                   File = $file;
                                                   Type = 'Sdk';
                                                   Name = $sdk;                                               
                                               }
                }
                else {
                    WriteProgress "  = Building failed."
                }
                
                $projectXml[0].Node.Sdk = $sdk
                $xml.Save($file.FullName)
            } else {
                WriteProgress "= SDK does not need changing. Currently $minimalSdk."
            }                   
        }
    
        [string[]]$allPackageIds = @()
        $packageReferences = $xml | Select-Xml -XPath "Project/ItemGroup/PackageReference"
        $projectReferences = $xml | Select-Xml -XPath "Project/ItemGroup/ProjectReference"
    
        foreach($node in $packageReferences)
        {
            if($node.Node.Include)
            {
                $packageId = $node.Node.Include
                $allPackageIds += $packageId
            }
        }
        
        $nodes = @($packageReferences) + @($projectReferences)
    
        foreach($node in $nodes) {
            if($node.Node.Include)
            {
                $doNotRemove = IsDoNotRemovePackage -PackageId $node.Node.Include -allPackageIds $allPackageIds
                if($doNotRemove)
                {
                    WriteProgress "= Skipping $( $node.Node.Include ) as it is marked as do not remove"
                    continue
                }
            }
            else {
                WriteProgress "= Skipping malformed include"
                continue
            }
            
            if($node.Node.PrivateAssets)
            {
                WriteProgress "= Skipping $( $node.Node.Include ) as it uses private assets"
                continue
            }
            
            $includeName = $node.Node.Include
            WriteProgress "Checking: $includeName"
    
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
                    WriteProgress "= $( $file.Name ) references package $( $node.Node.Include ) ($( $node.Node.Version )) that is also referenced in child project $( $existingChildInclude.File )."
                    $needToBuild = $false
                }
                else
                {
                    WriteProgress "* Building $( $file.Name ) without package $( $node.Node.Include ) ($( $node.Node.Version ))... "
                }
            }
            else
            {
                $existingChildInclude = $childProjectReferences | Where-Object { $_.Name -eq $node.Node.Include } | Select-Object -First 1
    
                if($existingChildInclude)
                {
                    WriteProgress "= $($file.Name) references project $($node.Node.Include) that is also referenced in child project $($existingChildInclude.File)."
                    $needToBuild = $false
                }
                else
                {
                    WriteProgress "* Building $($file.Name) without project $($node.Node.Include)... "
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
                WriteProgress "  - Building succeeded."
    
                if($node.Node.Version)
                {
                    $obsoletes += [PSCustomObject]@{
                        File = $file;
                        Type = 'Package';
                        Name = $node.Node.Include;
                        Version = $node.Node.Version;
                    }
                }
                else
                {
                    $obsoletes += [PSCustomObject]@{
                        File = $file;
                        Type = 'Project';
                        Name = $node.Node.Include;
                    }
                }
            }
            else
            {
                WriteProgress "  = Building failed."
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
        
        WriteSectionEnd "($projectInstance/$projectCount): Testing project: $($file.Name)"
    }

    WriteSectionEnd "Checking Projects"
        
    WriteProgress ""
    WriteProgress "-------------------------------------------------------------------------"
    WriteProgress "Analyse completed in $($stopWatch.Elapsed.TotalSeconds) seconds"
    WriteProgress "$($changeSdk.Length) SDK reference(s) could potentially be narrowed."
    WriteProgress "$($obsoletes.Length) reference(s) could potentially be removed."
    WriteProgress "$($reduceReferences.Length) reference(s) could potentially be switched to different packages."
    
    WriteStatistics -Section "SDK" -Value $changeSdk.Length
    WriteStatistics -Section "Obsolete" -Value $obsoletes.Length
    WriteStatistics -Section "Reduce" -Value $reduceReferences.Length
    
    WriteProgress "SDK:"
    $previousFile = $null
    foreach($sdkRef in $changeSdk)
    {
        if($previousFile -ne $sdkRef.File)
        {
            WriteProgress ""
            WriteProgress "Project: $($sdkRef.File.Name)"
        }
    
        WriteProgress "* Project reference: $($sdkRef.Name)"
    
        $previousFile = $sdkRef.File
    }
    
    
    WriteProgress "Obsolete:"
    $previousFile = $null
    foreach($obselete in $obsoletes)
    {
        if($previousFile -ne $obselete.File)
        {
            WriteProgress ""
            WriteProgress "Project: $($obselete.File.Name)"
        }
    
        if($obselete.Type -eq 'Package')
        {
            WriteProgress "* Package reference: $($obselete.Name) ($($obselete.Version))"
        }
        else
        {
            WriteProgress "* Project reference: $($obselete.Name)"
        }
    
        $previousFile = $obselete.File
    }
    
    WriteProgress ""
    WriteProgress "Reduce Scope:"
    $previousFile = $null
    foreach($reduce in $reduceReferences)
    {
        if($previousFile -ne $reduce.File)
        {
            WriteProgress ""
            WriteProgress "Project: $($reduce.File.Name)"
        }
    
        if($reduce.Type -eq 'Package')
        {
            WriteProgress "* Package reference: $($reduce.Name) ($($reduce.Version))"
        }
        else
        {
            WriteProgress "* Project reference: $($reduce.Name)"
        }
    
        $previousFile = $reduce.File
    }
    
    # No obsoletes and no SDK changes then exit code = 0 = Success
    $totalOptimisations = $obsoletes.Length + $changeSdk.Length + $reduceReferences.Length
    return $totalOptimisations
}

#########################################################################
#########################################################################
#########################################################################
#########################################################################


if(!$solutionDirectory.EndsWith("\")) {
    $solutionDirectory = $solutionDirectory + "\"
}

$result = CheckReferences -sourceDirectory $solutionDirectory

Exit $result

#########################################################################

