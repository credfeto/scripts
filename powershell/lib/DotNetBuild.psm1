
function DotNet-BuildClean {
    try {
        Write-Information " * Cleaning"
        $result = dotnet clean --configuration=Release -nodeReuse:False
        if(!$?) {
            Write-Information ">>> Clean Failed"
            Write-Information $result
            return $false
        }
        
        Write-Information "   - Clean Succeded"

        return $true
    } catch  {
        Write-Information ">>> Clean Failed"
        return $false
    }
}

function DotNet-BuildRestore {
    try {
        Write-Information " * Restoring"
        $result = dotnet restore -nodeReuse:False
        if(!$?) {
            Write-Information ">>> Restore Failed"
            Write-Information $result
            return $false
        }

        Write-Information "   - Restore Succeded"
        return $true
    } catch  {
        Write-Information ">>> Restore Failed"
        return $false
    }
}

function DotNet-Build {
    try {
        Write-Information " * Building"
        $result = dotnet build --configuration=Release --no-restore -warnAsError -nodeReuse:False
        if(!$?) {
            Write-Information ">>> Build Failed"
            Write-Information $result
            
            return $false
        }

        Write-Information "   - Build Succeded"

        return $true
    } catch  {
        Write-Information ">>> Build Failed"
        return $false
    }
}

function DotNet-Pack {
    try {
        Write-Information " * Packing"
        $result = dotnet pack --configuration=Release --no-build --no-restore -warnAsError -nodeReuse:False
        if(!$?) {
            Write-Information ">>> Packing Failed"
            Write-Information $result

            return $false
        }

        Write-Information "   - Packing Succeded"

        return $true
    } catch  {
        Write-Information ">>> Packing Failed"
        return $false
    }
}

function DotNet-Publish {
    try {
        Write-Information " * Publishing"
        $result = dotnet publish --configuration Release --no-restore -r linux-x64 --self-contained:true /p:PublishSingleFile=true /p:PublishReadyToRun=False /p:PublishReadyToRunShowWarnings=true /p:PublishTrimmed=False /p:DisableSwagger=False /p:TreatWarningsAsErrors=true /warnaserror /p:IncludeNativeLibrariesForSelfExtract=false -nodeReuse:False
        if(!$?) {
            Write-Information ">>> Publishing Failed"
            Write-Information $result

            return $false
        }

        Write-Information "   - Publishing Succeded"

        return $true
    } catch  {
        Write-Information ">>> Publishing Failed"
        return $false
    }
}

function DotNet-BuildRunUnitTestsLinux {
    try {
        Write-Information " * Unit Tests"
        $result = dotnet test --configuration Release --no-build --no-restore -nodeReuse:False --filter FullyQualifiedName\!~Integration
        if(!$?) {
            Write-Information ">>> Tests Failed"
            Write-Information $result
            return $false
        }

        Write-Information "   - Tests Succeded"
        return $true
    } catch  {
        Write-Information ">>> Tests Failed"
        return $false
    }
}

function DotNet-BuildRunUnitTestsWindows {
    try {

        Write-Information " * Unit Tests"
        $result = dotnet test --configuration Release --no-build --no-restore -nodeReuse:False --filter FullyQualifiedName!~Integration
        if(!$?) {
            # Didn't Build
            Write-Information ">>> Tests Failed"
            Write-Information $result
            return $false
        }

        Write-Information "   - Tests Succeded"
        return $true
    } catch  {
        # Didn't Build
        Write-Information ">>> Tests Failed"
        return $false
    }
}

function DotNet-BuildRunUnitTests {
    if($IsLinux -eq $true) {
        return DotNet-BuildRunUnitTestsLinux
    } else {
        return DotNet-BuildRunUnitTestsWindows
    }
}

function DotNet-BuildRunIntegrationTests {
    try {
        Write-Information " * Unit Tests and Integration Tests"
        $result = dotnet test --configuration Release --no-build --no-restore -nodeReuse:False
        if(!$?) {
            # Didn't Build
            Write-Information ">>> Tests Failed"
            Write-Information $result
            return $false;
        }

        Write-Information "   - Tests Succeded"
        return $true
    } catch  {
        # Didn't Build
        Write-Information ">>> Tests Failed"
        return $false
    }
}

function DotNet-HasPackable {
    param(
        [string] $srcFolder
    )

    $projects = Get-ChildItem -Path $srcFolder -Filter *.csproj -Recurse
    
    ForEach($project in $projects) {
        $projectFileName = $project.FullName
        Write-Information "* $projectFileName"

        $data = [xml](Get-Content $projectFileName)

        $projectType = $data.SelectSingleNode("/Project/PropertyGroup/OutputType");
        if($projectType -ne $null) {
            $projectTypeValue = $projectType.InnerText.Trim()
            Write-Information " --> $projectTypeValue"

            if($projectTypeValue -eq "Library") {
                $publishable = $data.SelectSingleNode("/Project/PropertyGroup/IsPackable");
                if($publishable -ne $null) {
                    $publishableValue = $publishable.InnerText.Trim()
                    if($publishableValue -eq "True") {
                        Write-Information " --> Packable"
                        return $true
                    }
                }
            }
        }
    }

    return $false
}

function DotNet-HasPublishableExe {
param(
    [string] $srcFolder
)

    $projects = Get-ChildItem -Path $srcFolder -Filter *.csproj -Recurse

    ForEach($project in $projects) {
        $projectFileName = $project.FullName
        Write-Information "* $projectFileName"

        $data = [xml](Get-Content $projectFileName)

        $projectType = $data.SelectSingleNode("/Project/PropertyGroup/OutputType");
        if($projectType -ne $null) {
            $projectTypeValue = $projectType.InnerText.Trim()
            Write-Information " --> $projectTypeValue"

            if($projectTypeValue -eq "Exe") {
                $publishable = $data.SelectSingleNode("/Project/PropertyGroup/IsPublishable");
                if($publishable -ne $null) {
                    $publishableValue = $publishable.InnerText.Trim()
                    if($publishableValue -eq "True") {
                        Write-Information " --> Publishable"
                        return $true
                    }
                }
            }
        }
    }

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

    
    $originalPath = (Get-Location).Path
    Set-Location -Path $srcFolder

    try
    {
        Write-Information "Building Source in $srcFolder"

        $buildOk = DotNet-BuildClean
        Write-Information "Result $buildOk" 
        if(!$buildOk) {
            return $false
        }
        
        $buildOk = DotNet-BuildRestore
        Write-Information "Result $buildOk"
        if(!$buildOk) {
            return $false
        }

        $buildOk = DotNet-Build
        Write-Information "Result $buildOk"
        if(!$buildOk) {
            return $false
        }
        
        $isPackable = DotNet-HasPackable -srcFolder $srcFolder
        if($isPublishable -eq $true) {
            $buildOk = DotNet-Pack
            Write-Information "Result $buildOk"
            if(!$buildOk) {
                return $false
            }
        }

        $isPublishable = DotNet-HasPublishableExe -srcFolder $srcFolder
        if($isPublishable -eq $true) {
            $buildOk = DotNet-Publish
            Write-Information "Result $buildOk"
            if(!$buildOk) {
                return $false
            }
        }
        
        if($runTests -ne $true)
        {
            return $true
        }
        
        if($includeIntegrationTests -eq $false) {
            $buildOk = DotNet-BuildRunUnitTests
            Write-Information "Result $buildOk"
            if(!$buildOk) {
                return $false
            }
        }
        else {
            $buildOk = DotNet-BuildRunIntegrationTests
            Write-Information "Result $buildOk"
            if(!$buildOk) {
                return $false
            }
        }
        
        return $true
    }
    catch {
        Write-Error "Something failed, badly!"
    }
    finally {


    # Restore the original path after any build.
    Set-Location -Path $originalPath
    }
    
}

Export-ModuleMember -Function DotNet-BuildSolution
