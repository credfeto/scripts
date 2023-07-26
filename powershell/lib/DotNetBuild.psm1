function BuildVersion {
    return "0.0.0.1-do-not-distribute"
}

function GetNoWarn {
    return '"-p:NoWarn=MSB3243,NU1802"'
}

function DotNet-DumpOutput {
    param(
         $result
    )

    foreach ($item in $result) {
        Write-Information ">>>>>> $item"
    }
}

function DotNet-IsMissingTool {
param(
    [string[]]$result
    )
    
    foreach($line in $result) {
        Write-Information $line
        if($line.Contains("dotnet tool restore")) {
            dotnet tool list
            throw "Missing dotnet tool"
        }
    }
}

function DotNet-ShutdownBuildServer {
    $results = dotnet build-server shutdown 2>$null > $null
    if(!$?) {        
        DotNet-DumpOutput -result $results
        #throw "Failed to shutdown build server"
    }
}

function DotNet-IsCodeAnalysisCrash {
param(
    $result
    )

    [string]$errorCode = 
    [string]$NewLine = [System.Environment]::NewLine

    [string]$resultsAsText = $result -join $NewLine
    
    # AD0001: Analyzer 'X' threw an exception of type 'Y'
    [bool]$retry = $resultsAsText.Contains("AD0001")    
    if($retry) {
        Write-Information ">>>>>> Code Analysis Crashed"
        return $true
    }
    
    # CS8034 - Unable to load Analyzer assembly X : Could not load file or assembly 'Y'. Access is denied.
    [bool]$retry = $resultsAsText.Contains("CS8034")    
    if($retry) {
        Write-Information ">>>>>> Code Analysis could not load assembly"
        return $true
    }
    
    return $false
}

function DotNet-GetPublishableFramework {
param(
    [string] $srcFolder = $(throw "DotNet-GetPublishableFramework: srcFolder not specified")
)
    $targets = @()

    $projects = Get-ChildItem -Path $srcFolder -Filter *.csproj -Recurse

    ForEach($project in $projects) {
        [string]$projectFileName = $project.FullName

        $data = [xml](Get-Content $projectFileName)

        $projectType = $data.SelectSingleNode("/Project/PropertyGroup/OutputType");
        if($projectType -ne $null) {
            $projectTypeValue = $projectType.InnerText.Trim()
            if($projectTypeValue -eq "Exe") {
                $publishable = $data.SelectSingleNode("/Project/PropertyGroup/TargetFramework");
                if($publishable -ne $null) {
                    $publishableValue = $publishable.InnerText.Trim()
                    if(!$targets.Contains($publishableValue)) {
                        $targets += $publishableValue
                    }
                }
                
                $publishable = $data.SelectSingleNode("/Project/PropertyGroup/TargetFrameworks");
                if($publishable -ne $null) {
                    $publishableValues = $publishable.InnerText.Trim().Split(";")
                    foreach($publishableValue in $publishableValues) {
                        if(!$targets.Contains($publishableValue)) {
                            $targets += $publishableValue
                        }
                    }
                }
            }
        }
    }
    
    if($targets) {
        $targets = $targets | Sort-Object
        
        Write-Information "Found Targets:"
        [string]$target = $null
        foreach($candidate in $targets) {
            Write-Information "* $candidate"
            $target = $candidate 
        }
        
        Write-Information "Matching Target : $target" 
        return $target
    }
    
    return [string]$null
}

function DotNet-CheckSolution {
param(
    [string] $srcFolder = $(throw "DotNet-CheckSolution: srcFolder not specified")
)
     
    Write-Information " * Checking Solution"
    try {
        Set-Location -Path $srcFolder
        
        $solutions = Get-ChildItem -Path $srcFolder -Filter *.sln
        if($solutions.Count -ne 1) {
            Write-Information " * No Solution Found"
            return $false
        }
        
        $solution = $solutions[0].FullName
        Write-Information " * Solution Found: $solution"
        
        DotNetTool-Require -packageId "FunFair.BuildCheck"
        Write-Information "dotnet buildcheck -Solution $solution -WarningAsErrors True -PreReleaseBuild True"
        $result = dotnet buildcheck -Solution $solution -WarningAsErrors True -PreReleaseBuild True
        if(!$?) {
            Write-Information ">>> Solution Check Failed"
            DotNet-DumpOutput -result $result
            DotNet-IsMissingTool -result $result            
            
            return $false
        }
        
        Write-Information "   - Solution Check Succeeded"

        return $true
    } catch  {
        Write-Information ">>> Solution Check Failed"
        return $false
    }
}


function DotNet-BuildClean {
param(
    [string] $srcFolder = $(throw "DotNet-BuildClean: srcFolder not specified")
)
     
    Write-Information " * Cleaning"
    try {
        Set-Location -Path $srcFolder

        DotNet-ShutdownBuildServer
        $result = dotnet clean --configuration=Release -nodeReuse:False  2>&1
        if(!$?) {
            Write-Information ">>> Clean Failed"
            DotNet-DumpOutput -result $result
            return $false
        }
        
        Write-Information "   - Clean Succeeded"
        return $true
    } catch  {
        Write-Information ">>> Clean Failed"
        return $false
    }
    finally {
        DotNet-ShutdownBuildServer
    }
}

function DotNet-BuildRestore {
param(
    [string] $srcFolder = $(throw "DotNet-BuildRestore: srcFolder not specified")
    )
     
    Write-Information " * Restoring"
    [string]$noWarn = GetNoWarn
    
    try {
        Set-Location -Path $srcFolder

        DotNet-ShutdownBuildServer
        $result = dotnet restore -nodeReuse:False -r:linux-x64 $noWarn 2>&1
        if(!$?) {
            Write-Information ">>> Restore Failed"
            DotNet-DumpOutput -result $result
            return $false
        }

        Write-Information "   - Restore Succeeded"
        return $true
    } catch  {
        Write-Information ">>> Restore Failed"
        return $false
    }
    finally {
        DotNet-ShutdownBuildServer
    }
}

function DotNet-Build {
param(
    [string] $srcFolder = $(throw "DotNet-Build: srcFolder not specified")
    )
     
    [string]$version = BuildVersion
    [string]$noWarn = GetNoWarn

    Write-Information " * Building"
    do {
        Set-Location -Path $srcFolder

        DotNet-ShutdownBuildServer
        $result = dotnet build --no-restore -warnAsError -nodeReuse:False --configuration=Release -p:Version=$version $noWarn  2>&1
        if(!$?) {
            [bool]$retry = DotNet-IsCodeAnalysisCrash -result $result
            if (!$retry) {
                Write-Information ">>> Build Failed"
                DotNet-DumpOutput -result $result
                DotNet-ShutdownBuildServer
                return $false
            }
        }
        else {
            Write-Information "   - Build Succeeded"
            DotNet-ShutdownBuildServer
            return $true
        }
    }
    while($true)
}

function DotNet-Pack {
param(
    [string] $srcFolder = $(throw "DotNet-Pack: srcFolder not specified")
    )
     
    [string]$version = BuildVersion    
    [string]$noWarn = GetNoWarn
    
    Write-Information " * Packing"
    do {
        Set-Location -Path $srcFolder

        DotNet-ShutdownBuildServer
        $result = dotnet pack --no-restore -nodeReuse:False --configuration=Release -p:Version=$version $noWarn 2>&1
        if(!$?) {
            [bool]$retry = DotNet-IsCodeAnalysisCrash -result $result
            if (!$retry) {
                Write-Information ">>> Packing Failed"
                DotNet-DumpOutput -result $result
                DotNet-ShutdownBuildServer
                return $false
            }
        }
        else {
            Write-Information "   - Packing Succeeded"
            DotNet-ShutdownBuildServer
            return $true
        }
    }
    while($true)
}

function DotNet-Publish {
param(
    [string] $srcFolder = $(throw "DotNet-Publish: srcFolder not specified")
    )
    
    [string]$framework = DotNet-GetPublishableFramework -srcFolder $srcFolder
     
    [string]$version = BuildVersion

    [string]$noWarn = GetNoWarn 
    
    Write-Information " * Publishing"
    do {
        Set-Location -Path $srcFolder

        DotNet-ShutdownBuildServer
        if($framework) {
            $result = dotnet publish -warnaserror -p:PublishSingleFile=true --configuration:Release -r:linux-x64 --framework:$framework --self-contained -p:PublishReadyToRun=False -p:PublishReadyToRunShowWarnings=True -p:PublishTrimmed=False -p:DisableSwagger=False -p:TreatWarningsAsErrors=True -p:Version=$version -p:IncludeNativeLibrariesForSelfExtract=false $noWarn -nodeReuse:False 2>&1
        } else {
            $result = dotnet publish -warnaserror -p:PublishSingleFile=true --configuration:Release -r:linux-x64 --self-contained -p:PublishReadyToRun=False -p:PublishReadyToRunShowWarnings=True -p:PublishTrimmed=False -p:DisableSwagger=False -p:TreatWarningsAsErrors=True -p:Version=$version -p:IncludeNativeLibrariesForSelfExtract=false $noWarn -nodeReuse:False 2>&1
        }
        if (!$?) {
            [bool]$retry = DotNet-IsCodeAnalysisCrash -result $result
            if (!$retry)
            {
                Write-Information ">>> Publishing Failed"
                DotNet-DumpOutput -result $result
                DotNet-ShutdownBuildServer
                return $false
            }
        }
        else {
            Write-Information "   - Publishing Succeeded"
            DotNet-ShutdownBuildServer
            return $true
        }
    }
    while($true)
}

function DotNet-BuildRunUnitTestsLinux {
param(
    [string] $srcFolder = $(throw "DotNet-BuildRunUnitTestsLinux: srcFolder not specified")
    )
     
    [string]$noWarn = GetNoWarn
    Write-Information " * Unit Tests"
    do {
        Set-Location -Path $srcFolder

        DotNet-ShutdownBuildServer
        $result = dotnet test --configuration Release --no-build --no-restore -nodeReuse:False --filter FullyQualifiedName\!~Integration $noWarn 2>&1
        if (!$?) {
            [bool]$retry = DotNet-IsCodeAnalysisCrash -result $result
            if (!$retry) {
                Write-Information ">>> Tests Failed"
                DotNet-DumpOutput -result $result
                DotNet-ShutdownBuildServer
                return $false
            }
        }
        else {
            Write-Information "   - Tests Succeeded"
            DotNet-ShutdownBuildServer
            return $true
        }            
    }
    while($true)
}

function DotNet-BuildRunUnitTestsWindows {
param(
    [string] $srcFolder = $(throw "DotNet-BuildRunUnitTestsWindows: srcFolder not specified")
    )
     
    [string]$noWarn = GetNoWarn
    Write-Information " * Unit Tests"
    do {
        Set-Location -Path $srcFolder

        DotNet-ShutdownBuildServer
        $result = dotnet test --configuration Release --no-build --no-restore -nodeReuse:False --filter FullyQualifiedName!~Integration $noWarn 2>&1
        if (!$?) {
            [bool]$retry = DotNet-IsCodeAnalysisCrash -result $result
            if (!$retry) {
                Write-Information ">>> Tests Failed"
                DotNet-DumpOutput -result $result
                DotNet-ShutdownBuildServer
                return $false
            }
        }
        else {
            Write-Information "   - Tests Succeeded"
            DotNet-ShutdownBuildServer
            return $true
        }
    }
    while($true)
}

function DotNet-BuildRunUnitTests {
param(
    [string] $srcFolder = $(throw "DotNet-BuildRunUnitTests: srcFolder not specified")
)

    if($IsLinux -eq $true) {
        return DotNet-BuildRunUnitTestsLinux -srcFolder $srcFolder
    } else {
        return DotNet-BuildRunUnitTestsWindows -srcFolder $srcFolder
    }
}

function DotNet-BuildRunIntegrationTests {
param(
    [string] $srcFolder = $(throw "DotNet-BuildRunIntegrationTests: srcFolder not specified")
)

    [string]$noWarn = GetNoWarn
    
    Write-Information " * Unit Tests and Integration Tests"
    do {
        Set-Location -Path $srcFolder

        DotNet-ShutdownBuildServer
        $result = dotnet test --configuration Release --no-build --no-restore -nodeReuse:False $noWarn 2>&1
        if (!$?) {
            [bool]$retry = DotNet-IsCodeAnalysisCrash -result $result
            if (!$retry) {
                Write-Information ">>> Tests Failed"
                DotNet-DumpOutput -result $result
                DotNet-ShutdownBuildServer
                return $false
            }
        }
        else {
            Write-Information "   - Tests Succeeded"
            DotNet-ShutdownBuildServer
            return $true
        }
    }
    while($true)
}

function DotNet-HasPackable {
    param(
        [string] $srcFolder = $(throw "DotNet-HasPackable: srcFolder not specified")
    )

    $projects = Get-ChildItem -Path $srcFolder -Filter *.csproj -Recurse
    
    ForEach($project in $projects) {
        [string]$projectFileName = $project.FullName

        $data = [xml](Get-Content $projectFileName)

        $projectType = $data.SelectSingleNode("/Project/PropertyGroup/OutputType");
        if($projectType -ne $null) {
            [string]$projectTypeValue = $projectType.InnerText.Trim()

            if($projectTypeValue -eq "Library") {
                $publishable = $data.SelectSingleNode("/Project/PropertyGroup/IsPackable");
                if($publishable -ne $null) {
                    [string]$publishableValue = $publishable.InnerText.Trim()
                    if($publishableValue -eq "True") {
                        Write-Information "*** Found Packable Library"
                        return $true
                    }
                }
            }
        }
    }

    Write-Information "*** No Packable Library Found"
    return $false
}

function DotNet-HasPublishableExe {
param(
    [string] $srcFolder = $(throw "DotNet-HasPublishableExe: srcFolder not specified")
)

    $projects = Get-ChildItem -Path $srcFolder -Filter *.csproj -Recurse

    ForEach($project in $projects) {
        [string]$projectFileName = $project.FullName

        $data = [xml](Get-Content $projectFileName)

        $projectType = $data.SelectSingleNode("/Project/PropertyGroup/OutputType");
        if($projectType -ne $null) {
            [string]$projectTypeValue = $projectType.InnerText.Trim()
            if($projectTypeValue -eq "Exe") {
                $publishable = $data.SelectSingleNode("/Project/PropertyGroup/IsPublishable");
                if($publishable -ne $null) {
                    [string]$publishableValue = $publishable.InnerText.Trim()
                    if($publishableValue -eq "True") {
                        Write-Information "*** Found Publishable Executable"
                        return $true
                    }
                }
            }
        }
    }

    Write-Information "*** No Publishable Executable Found"
    return $false
}

<#
 .Synopsis
  Builds a .net core solution

 .Description
  Builds a .net core solution

 .Parameter baseFolder
  The Base folder that contains the source

 .Parameter runTests
  Whether to run tests (default=true)

 .Parameter includeIntegrationTests
  Whether to run integration tests (default=false)
#>
function DotNet-BuildSolution {
param(
    [string] $srcFolder = $(throw "DotNet-BuildSolution: srcFolder not specified"), 
    [bool] $runTests = $true, 
    [bool] $includeIntegrationTests = $false
    )

    [string]$originalPath = (Get-Location).Path
    Set-Location -Path $srcFolder

    try
    {
        Write-Information "Building Source in $srcFolder"
        
        [bool]$buildOk = DotNet-CheckSolution -srcFolder $srcFolder
        Write-Information "Result $buildOk" 
        if(!$buildOk) {
            return $false
        }

        [bool]$buildOk = DotNet-BuildClean -srcFolder $srcFolder
        Write-Information "Result $buildOk" 
        if(!$buildOk) {
            return $false
        }
        
        [bool]$buildOk = DotNet-BuildRestore -srcFolder $srcFolder
        Write-Information "Result $buildOk"
        if(!$buildOk) {
            return $false
        }

        [bool]$buildOk = DotNet-Build -srcFolder $srcFolder
        Write-Information "Result $buildOk"
        if(!$buildOk) {
            return $false
        }
        
        [bool]$isPackable = DotNet-HasPackable -srcFolder $srcFolder
        if($isPackable -eq $true) {
            [bool]$buildOk = DotNet-Pack -srcFolder $srcFolder
            Write-Information "Result $buildOk"
            if(!$buildOk) {
                return $false
            }
        }

        [bool]$isPublishable = DotNet-HasPublishableExe -srcFolder $srcFolder
        if($isPublishable -eq $true) {
            [bool]$buildOk = DotNet-Publish -srcFolder $srcFolder
            Write-Information "Result $buildOk"
            if(!$buildOk) {
                return $false
            }
        }
        
        if($runTests -ne $true) {
            return $true
        }
        
        if($includeIntegrationTests -eq $false) {
            [bool]$buildOk = DotNet-BuildRunUnitTests -srcFolder $srcFolder
            Write-Information "Result $buildOk"
            if(!$buildOk) {
                return $false
            }
        }
        else {
            [bool]$buildOk = DotNet-BuildRunIntegrationTests -srcFolder $srcFolder
            Write-Information "Result $buildOk"
            if(!$buildOk) {
                return $false
            }
        }
        
        return $true
    }
    catch {
        Write-Error "Something failed, badly!"
        return $false
    }
    finally {
        DotNet-ShutdownBuildServer
        # Restore the original path after any build.
        Set-Location -Path $originalPath
    }
    
}

Export-ModuleMember -Function DotNet-CheckSolution
Export-ModuleMember -Function DotNet-BuildSolution
Export-ModuleMember -Function DotNet-HasPackable
Export-ModuleMember -Function DotNet-HasPublishableExe