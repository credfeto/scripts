function BuildVersion {
    return "0.0.0.1-do-not-distribute"
}

function DotNet-DumpOutput {
    param(
         $result
    )

    foreach ($item in $result) {
        Write-Information ">>>>>> $item"
    }
}

function DotNet-GetPublishableFramework {
param(
    [string] $srcFolder
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

function DotNet-BuildClean {
param(
    [string] $srcFolder)
     
    Write-Information " * Cleaning"
    try {
        Set-Location -Path $srcFolder

        $result = dotnet clean --configuration=Release -nodeReuse:False
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
}

function DotNet-BuildRestore {
param(
    [string] $srcFolder)
     
    Write-Information " * Restoring"
    try {
        Set-Location -Path $srcFolder

        $result = dotnet restore -nodeReuse:False -r:linux-x64
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
}

function DotNet-Build {
param(
    [string] $srcFolder)
     
    [string]$errorCode = "AD0001"
    [string]$NewLine = [System.Environment]::NewLine
    [string]$version = BuildVersion

    Write-Information " * Building"
    do {
        Set-Location -Path $srcFolder

        $result = dotnet build --no-restore -warnAsError -nodeReuse:False --configuration=Release -p:Version=$version
        if(!$?) {
            [string]$resultsAsText = $results -join $NewLine
            [bool]$retry = $resultsAsText.Contains($errorCode)
            if (!$retry) {
                Write-Information ">>> Build Failed"
                DotNet-DumpOutput -result $result
                return $false
            }
        }
        else {
            Write-Information "   - Build Succeeded"

            return $true
        }
    }
    while($true)
}

function DotNet-Pack {
param(
    [string] $srcFolder)
     
    [string]$errorCode = "AD0001"
    [string]$NewLine = [System.Environment]::NewLine
    [string]$version = BuildVersion
    
    Write-Information " * Packing"
    do {
        Set-Location -Path $srcFolder

        $result = dotnet pack --no-restore -nodeReuse:False --configuration=Release -p:Version=$version
        if(!$?) {
            [string]$resultsAsText = $results -join $NewLine
            [bool]$retry = $resultsAsText.Contains($errorCode)
            if (!$retry) {
                Write-Information ">>> Packing Failed"
                DotNet-DumpOutput -result $result

                return $false
            }
        }
        else {
            Write-Information "   - Packing Succeeded"

            return $true
        }
    }
    while($true)
}

function DotNet-Publish {
param(
    [string] $srcFolder)
    
    [string]$framework = DotNet-GetPublishableFramework -srcFolder $srcFolder
     
    [string]$errorCode = "AD0001"
    [string]$NewLine = [System.Environment]::NewLine
    [string]$version = BuildVersion

    Write-Information " * Publishing"
    do {
        Set-Location -Path $srcFolder

        if($framework) {
            $result = dotnet publish --no-restore -warnaserror -p:PublishSingleFile=true --configuration:Release -r:linux-x64 --framework:$framework --self-contained:true -p:PublishReadyToRun=False -p:PublishReadyToRunShowWarnings=True -p:PublishTrimmed=False -p:DisableSwagger=False -p:TreatWarningsAsErrors=True -p:Version=$version -p:IncludeNativeLibrariesForSelfExtract=false -nodeReuse:False
        } else {
            $result = dotnet publish --no-restore -warnaserror -p:PublishSingleFile=true --configuration:Release -r:linux-x64 --self-contained:true -p:PublishReadyToRun=False -p:PublishReadyToRunShowWarnings=True -p:PublishTrimmed=False -p:DisableSwagger=False -p:TreatWarningsAsErrors=True -p:Version=$version -p:IncludeNativeLibrariesForSelfExtract=false -nodeReuse:False
        }
        if (!$?) {
            [string]$resultsAsText = $results -join $NewLine
            [bool]$retry = $resultsAsText.Contains($errorCode)
            if (!$retry)
            {
                Write-Information ">>> Publishing Failed"
                DotNet-DumpOutput -result $result

                return $false
            }
        }
        else {
            Write-Information "   - Publishing Succeeded"
            return $true
        }
    }
    while($true)
}

function DotNet-BuildRunUnitTestsLinux {
param(
    [string] $srcFolder)
     
    [string]$errorCode = "AD0001"
    [string]$NewLine = [System.Environment]::NewLine

    Write-Information " * Unit Tests"
    do {
        Set-Location -Path $srcFolder

        $result = dotnet test --configuration Release --no-build --no-restore -nodeReuse:False --filter FullyQualifiedName\!~Integration
        if (!$?) {
            [string]$resultsAsText = $results -join $NewLine
            [bool]$retry = $resultsAsText.Contains($errorCode)
            if (!$retry) {
                Write-Information ">>> Tests Failed"
                DotNet-DumpOutput -result $result
                return $false
            }
        }
        else {
            Write-Information "   - Tests Succeeded"
            return $true
        }            
    }
    while($true)
}

function DotNet-BuildRunUnitTestsWindows {
param(
    [string] $srcFolder)
     
    [string]$errorCode = "AD0001"
    [string]$NewLine = [System.Environment]::NewLine

    Write-Information " * Unit Tests"
    do {
        Set-Location -Path $srcFolder

        $result = dotnet test --configuration Release --no-build --no-restore -nodeReuse:False --filter FullyQualifiedName!~Integration
        if (!$?) {
            [string]$resultsAsText = $results -join $NewLine
            [bool]$retry = $resultsAsText.Contains($errorCode)
            if (!$retry) {
                Write-Information ">>> Tests Failed"
                DotNet-DumpOutput -result $result
                return $false
            }
        }
        else {
            Write-Information "   - Tests Succeeded"
            return $true
        }
    }
    while($true)
}

function DotNet-BuildRunUnitTests {
param(
    [string] $srcFolder
)

    if($IsLinux -eq $true) {
        return DotNet-BuildRunUnitTestsLinux -srcFolder $srcFolder
    } else {
        return DotNet-BuildRunUnitTestsWindows -srcFolder $srcFolder
    }
}

function DotNet-BuildRunIntegrationTests {
param(
    [string] $srcFolder
)

    [string]$errorCode = "AD0001"
    [string]$NewLine = [System.Environment]::NewLine

    Write-Information " * Unit Tests and Integration Tests"
    do {
        Set-Location -Path $srcFolder

        $result = dotnet test --configuration Release --no-build --no-restore -nodeReuse:False
        if (!$?) {
            [string]$resultsAsText = $results -join $NewLine
            [bool]$retry = $resultsAsText.Contains($errorCode)
            if (!$retry) {
                Write-Information ">>> Tests Failed"
                DotNet-DumpOutput -result $result
                return $false
            }
        }
        else {
            Write-Information "   - Tests Succeeded"
            return $true
        }
    }
    while($true)
}

function DotNet-HasPackable {
    param(
        [string] $srcFolder
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
    [string] $srcFolder
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
    [string] $srcFolder, 
    [bool] $runTests = $true, 
    [bool] $includeIntegrationTests = $false
    )

    [string]$originalPath = (Get-Location).Path
    Set-Location -Path $srcFolder

    try
    {
        Write-Information "Building Source in $srcFolder"

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
        # Restore the original path after any build.
        Set-Location -Path $originalPath
    }
    
}

Export-ModuleMember -Function DotNet-BuildSolution
Export-ModuleMember -Function DotNet-HasPackable
Export-ModuleMember -Function DotNet-HasPublishableExe