
function DotNet-DumpOutput {
    param(
         $result
    )

    foreach ($item in $result) {
        Write-Information ">>>>>> $item"
    }
}


function DotNet-BuildClean {
    try {
        Write-Information " * Cleaning"
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
    try {
        Write-Information " * Restoring"
        $result = dotnet restore -nodeReuse:False -r linux-x64
        if(!$?) {
            Write-Information ">>> Restore Failed"
            DotNet-DumpOutput -result $result
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

    $errorCode = "AD0001"
    $NewLine = [System.Environment]::NewLine

    Write-Information " * Building"
    do {
        $result = dotnet build --configuration=Release --no-restore -warnAsError -nodeReuse:False /p:Version=0.0.0.1-do-not-distribute
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
            Write-Information "   - Build Succeded"

            return $true
        }
    }
    while($true)
}

function DotNet-Pack {
    $errorCode = "AD0001"
    $NewLine = [System.Environment]::NewLine

    Write-Information " * Packing"
    do {
        $result = dotnet pack --configuration=Release --no-build --no-restore -nodeReuse:False /p:Version=0.0.0.1-do-not-distribute
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
            Write-Information "   - Packing Succeded"

            return $true
        }
    }
    while($true)
}

function DotNet-Publish {
    $errorCode = "AD0001"
    $NewLine = [System.Environment]::NewLine

    Write-Information " * Publishing"
    do
    {
        $result = dotnet publish --configuration Release --no-restore -r linux-x64 --self-contained:true /p:PublishSingleFile=true /p:PublishReadyToRun=False /p:PublishReadyToRunShowWarnings=true /p:PublishTrimmed=False /p:DisableSwagger=False /p:TreatWarningsAsErrors=true /p:Version=0.0.0.1-do-not-distribute /warnaserror /p:IncludeNativeLibrariesForSelfExtract=false -nodeReuse:False
        if (!$?)
        {
            $resultsAsText = $results -join $NewLine
            $retry = $resultsAsText.Contains($errorCode)
            if (!$retry)
            {
                Write-Information ">>> Publishing Failed"
                DotNet-DumpOutput -result $result

                return $false
            }
        }
        else
        {
            Write-Information "   - Publishing Succeded"
            return $true
        }
    }
    while($true)
}

function DotNet-BuildRunUnitTestsLinux {
    $errorCode = "AD0001"
    $NewLine = [System.Environment]::NewLine

    Write-Information " * Unit Tests"
    do
    {
        $result = dotnet test --configuration Release --no-build --no-restore -nodeReuse:False --filter FullyQualifiedName\!~Integration
        if (!$?)
        {
            $resultsAsText = $results -join $NewLine
            $retry = $resultsAsText.Contains($errorCode)
            if (!$retry)
            {
                Write-Information ">>> Tests Failed"
                DotNet-DumpOutput -result $result
                return $false
            }
        }
        else
        {
            Write-Information "   - Tests Succeded"
            return $true
        }            
    }
    while($true)
}

function DotNet-BuildRunUnitTestsWindows {
    $errorCode = "AD0001"
    $NewLine = [System.Environment]::NewLine

    Write-Information " * Unit Tests"
    do
    {
        $result = dotnet test --configuration Release --no-build --no-restore -nodeReuse:False --filter FullyQualifiedName!~Integration
        if (!$?)
        {
            $resultsAsText = $results -join $NewLine
            $retry = $resultsAsText.Contains($errorCode)
            if (!$retry)
            {
                Write-Information ">>> Tests Failed"
                DotNet-DumpOutput -result $result
                return $false
            }
        }
        else
        {
            Write-Information "   - Tests Succeded"
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
    do
    {
        $result = dotnet test --configuration Release --no-build --no-restore -nodeReuse:False
        if (!$?)
        {
            $resultsAsText = $results -join $NewLine
            $retry = $resultsAsText.Contains($errorCode)
            if (!$retry)
            {
                Write-Information ">>> Tests Failed"
                DotNet-DumpOutput -result $result
                return $false
            }
        }
        else
        {
            Write-Information "   - Tests Succeded"
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
        if($isPackable -eq $true) {
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