
#########################################################################
# https://devblog.pekspro.com/posts/finding-redundant-project-references
#########################################################################

param(
    [string] $solutionDirectory = $(throw "Directory containing projects")
)


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

function BuildProject {
    param([string]$FileName, [bool]$FullError)

    do
    {
        $results = dotnet build $file.FullName -warnAsError -nodeReuse:False /p:SolutionDir=$solutionDirectory
        if(!$?) {
            #Write-Host "**** FAILED ****"
            $retry = $results.Contains("CSC : error AD0001:")
            if(!$retry)
            {
                if($FullError)
                {
                    Write-Host $results
                }
                return $false
            }
        }
        else {
            #Write-Host "**** SUCCESS ****" 
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


$files = Get-ChildItem -Path $solutionDirectory -Filter *.csproj -Recurse

if(!$solutionDirectory.EndsWith("\")) {
    $solutionDirectory = $solutionDirectory + "\"
    Write-Output $solutionDirectory
}

Write-Output "Number of projects: $($files.Length)"

$stopWatch = [System.Diagnostics.Stopwatch]::startNew()

$obseletes = @()

$projectCount = $files.Length
$projectInstance = 0

foreach($file in $files) {

    $projectInstance = $projectInstance + 1
    
    Write-Output ""
    Write-Output "($projectInstance/$projectCount): Testing project: $($file.Name)"

    $rawFileContent = [System.IO.File]::ReadAllBytes($file.FullName)

    $buildOk = BuildProject -FileName $file.FullName -FullError $true
    if(!$buildOk) {
        Write-Output " * Does not build without changes"
        continue
    }
    
    $childPackageReferences = Get-PackageReferences $file.FullName $false $true
    $childProjectReferences = Get-ProjectReferences $file.FullName $false $true

    $xml = [xml] (Get-Content $file.FullName)

    $packageReferences = $xml | Select-Xml -XPath "Project/ItemGroup/PackageReference"
    $projectReferences = $xml | Select-Xml -XPath "Project/ItemGroup/ProjectReference"

    $nodes = @($packageReferences) + @($projectReferences)

    foreach($node in $nodes)
    {
        if($node.Node.PrivateAssets)
        {
            continue
        }

        if($node.Node.Include)
        {
            $doNotRemove = IsDoNotRemovePackage -PackageId $node.Node.Include
            if($doNotRemove)
            {
                continue
            }
        }

        $previousNode = $node.Node.PreviousSibling
        $parentNode = $node.Node.ParentNode
        $parentNode.RemoveChild($node.Node) > $null
        
        $needToBuild = $true
        if($node.Node.Include)
        {
            $xml.Save($file.FullName)

            if($node.Node.Version)
            {
                $existingChildInclude = $childPackageReferences | Where-Object { $_.Name -eq $node.Node.Include -and $_.Version -eq $node.Node.Version } | Select-Object -First 1

                if ($existingChildInclude)
                {
                    Write-Output "$( $file.Name ) references package $( $node.Node.Include ) ($( $node.Node.Version )) that is also referenced in child project $( $existingChildInclude.File )."
                    $needToBuild = $false
                }
                else
                {
                    Write-Host -NoNewline "Building $( $file.Name ) without package $( $node.Node.Include ) ($( $node.Node.Version ))... "
                }
            }
            else
            {
                $existingChildInclude = $childProjectReferences | Where-Object { $_.Name -eq $node.Node.Include } | Select-Object -First 1

                if($existingChildInclude)
                {
                    Write-Output "$($file.Name) references project $($node.Node.Include) that is also referenced in child project $($existingChildInclude.File)."
                    $needToBuild = $false
                }
                else
                {
                    Write-Host -NoNewline "Building $($file.Name) without project $($node.Node.Include)... "
                }
            }
        }
        else
        {
            continue
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
            Write-Output "Building succeeded."

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
            Write-Output "Building failed."
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
        Write-Error "Failed to build $($file.FullName) after project file restore. Was project broken before?"
        return
    }
}

Write-Output ""
Write-Output "-------------------------------------------------------------------------"
Write-Output "Analyse completed in $($stopWatch.Elapsed.TotalSeconds) seconds"
Write-Output "$($obseletes.Length) reference(s) could potentially be removed."

$previousFile = $null
foreach($obselete in $obseletes)
{
    if($previousFile -ne $obselete.File)
    {
        Write-Output ""
        Write-Output "Project: $($obselete.File.Name)"
    }

    if($obselete.Type -eq 'Package')
    {
        Write-Output "* Package reference: $($obselete.Name) ($($obselete.Version))"
    }
    else
    {
        Write-Output "* Project refence: $($obselete.Name)"
    }

    $previousFile = $obselete.File
}