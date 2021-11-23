
function DotNet-DumpOutput {
    param(
         $result
    )

    foreach ($item in $result) {
        Write-Information ">>>>>> $item"
    }
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
        
        Write-Information "   - Clean Succeded"

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
     
    $errorCode = "AD0001"
    $NewLine = [System.Environment]::NewLine

    Write-Information " * Building"
    do {
        Set-Location -Path $srcFolder

        $result = dotnet build --no-restore -warnAsError --configuration=Release -nodeReuse:False -p:Version=0.0.0.1-do-not-distribute
        if(!$?) {
            $resultsAsText = $results -join $NewLine
            $retry = $resultsAsText.Contains($errorCode)
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
     
    $errorCode = "AD0001"
    $NewLine = [System.Environment]::NewLine

    Write-Information " * Packing"
    do {
        Set-Location -Path $srcFolder

        $result = dotnet pack --no-build --no-restore --configuration=Release -nodeReuse:False -p:Version=0.0.0.1-do-not-distribute
        if(!$?) {
            $resultsAsText = $results -join $NewLine
            $retry = $resultsAsText.Contains($errorCode)
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
     
    $errorCode = "AD0001"
    $NewLine = [System.Environment]::NewLine

    Write-Information " * Publishing"
    do {
        Set-Location -Path $srcFolder

        $result = dotnet publish --no-restore -warnaserror -p:PublishSingleFile=true --configuration:Release -r:linux-x64 --self-contained:true -p:PublishReadyToRun=False -p:PublishReadyToRunShowWarnings=True -p:PublishTrimmed=False -p:DisableSwagger=False -p:TreatWarningsAsErrors=True -p:Version=0.0.0.1-do-not-distribute -p:IncludeNativeLibrariesForSelfExtract=false -nodeReuse:False
        if (!$?) {
            $resultsAsText = $results -join $NewLine
            $retry = $resultsAsText.Contains($errorCode)
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
     
    $errorCode = "AD0001"
    $NewLine = [System.Environment]::NewLine

    Write-Information " * Unit Tests"
    do {
        Set-Location -Path $srcFolder

        $result = dotnet test --configuration Release --no-build --no-restore -nodeReuse:False --filter FullyQualifiedName\!~Integration
        if (!$?) {
            $resultsAsText = $results -join $NewLine
            $retry = $resultsAsText.Contains($errorCode)
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
     
    $errorCode = "AD0001"
    $NewLine = [System.Environment]::NewLine

    Write-Information " * Unit Tests"
    do {
        Set-Location -Path $srcFolder

        $result = dotnet test --configuration Release --no-build --no-restore -nodeReuse:False --filter FullyQualifiedName!~Integration
        if (!$?) {
            $resultsAsText = $results -join $NewLine
            $retry = $resultsAsText.Contains($errorCode)
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
    if($IsLinux -eq $true) {
        return DotNet-BuildRunUnitTestsLinux
    } else {
        return DotNet-BuildRunUnitTestsWindows
    }
}

function DotNet-BuildRunIntegrationTests {
    $errorCode = "AD0001"
    $NewLine = [System.Environment]::NewLine

    Write-Information " * Unit Tests and Integration Tests"
    do {
        Set-Location -Path $srcFolder

        $result = dotnet test --configuration Release --no-build --no-restore -nodeReuse:False
        if (!$?) {
            $resultsAsText = $results -join $NewLine
            $retry = $resultsAsText.Contains($errorCode)
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
        $projectFileName = $project.FullName

        $data = [xml](Get-Content $projectFileName)

        $projectType = $data.SelectSingleNode("/Project/PropertyGroup/OutputType");
        if($projectType -ne $null) {
            $projectTypeValue = $projectType.InnerText.Trim()

            if($projectTypeValue -eq "Library") {
                $publishable = $data.SelectSingleNode("/Project/PropertyGroup/IsPackable");
                if($publishable -ne $null) {
                    $publishableValue = $publishable.InnerText.Trim()
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
        $projectFileName = $project.FullName

        $data = [xml](Get-Content $projectFileName)

        $projectType = $data.SelectSingleNode("/Project/PropertyGroup/OutputType");
        if($projectType -ne $null) {
            $projectTypeValue = $projectType.InnerText.Trim()
            if($projectTypeValue -eq "Exe") {
                $publishable = $data.SelectSingleNode("/Project/PropertyGroup/IsPublishable");
                if($publishable -ne $null) {
                    $publishableValue = $publishable.InnerText.Trim()
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

    
    $originalPath = (Get-Location).Path
    Set-Location -Path $srcFolder

    try
    {
        Write-Information "Building Source in $srcFolder"

        $buildOk = DotNet-BuildClean -srcFolder $srcFolder
        Write-Information "Result $buildOk" 
        if(!$buildOk) {
            return $false
        }
        
        $buildOk = DotNet-BuildRestore -srcFolder $srcFolder
        Write-Information "Result $buildOk"
        if(!$buildOk) {
            return $false
        }

        $buildOk = DotNet-Build -srcFolder $srcFolder
        Write-Information "Result $buildOk"
        if(!$buildOk) {
            return $false
        }
        
        $isPackable = DotNet-HasPackable -srcFolder $srcFolder
        if($isPackable -eq $true) {
            $buildOk = DotNet-Pack -srcFolder $srcFolder
            Write-Information "Result $buildOk"
            if(!$buildOk) {
                return $false
            }
        }

        $isPublishable = DotNet-HasPublishableExe -srcFolder $srcFolder
        if($isPublishable -eq $true) {
            $buildOk = DotNet-Publish -srcFolder $srcFolder
            Write-Information "Result $buildOk"
            if(!$buildOk) {
                return $false
            }
        }
        
        if($runTests -ne $true) {
            return $true
        }
        
        if($includeIntegrationTests -eq $false) {
            $buildOk = DotNet-BuildRunUnitTests -srcFolder $srcFolder
            Write-Information "Result $buildOk"
            if(!$buildOk) {
                return $false
            }
        }
        else {
            $buildOk = DotNet-BuildRunIntegrationTests -srcFolder $srcFolder
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