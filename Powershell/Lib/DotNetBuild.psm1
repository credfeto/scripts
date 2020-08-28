
function DotNet-BuildClean {
    try {
        Write-Host " * Cleaning"
        dotnet clean --configuration=Release 
        if(!$?) {
            Write-Host ">>> Clean Failed"
            return $false
        }
        
        Write-Host "   - Clean Succeded"

        return $true
    } catch  {
        Write-Host ">>> Clean Failed"
        return $false
    }
}

function DotNet-BuildRestore {
    try {
        Write-Host " * Restoring"
        dotnet restore
        if(!$?) {
            Write-Host ">>> Restore Failed"
            return $false
        }

        Write-Host "   - Restore Succeded"
        return $true
    } catch  {
        Write-Host ">>> Restore Failed"
        return $false
    }
}

function DotNet-Build {
    try {
        Write-Host " * Building"
        dotnet build --configuration=Release --no-restore -warnAsError
        if(!$?) {
            Write-Host ">>> Build Failed"
            
            return $false
        }

        Write-Host "   - Build Succeded"

        return $true
    } catch  {
        Write-Host ">>> Build Failed"
        return $false
    }
}

function DotNet-BuildRunUnitTestsLinux {
    try {
        Write-Host " * Unit Tests"
        dotnet test --configuration Release --no-build --no-restore --filter FullyQualifiedName\!~Integration
        if(!$?) {
            Write-Host ">>> Tests Failed"
            return $false
        }

        Write-Host "   - Tests Succeded"
        return $true
    } catch  {
        Write-Host ">>> Tests Failed"
        return $false
    }
}

function DotNet-BuildRunUnitTestsWindows {
    try {

        Write-Host " * Unit Tests"
        dotnet test --configuration Release --no-build --no-restore --filter FullyQualifiedName!~Integration
        if(!$?) {
            # Didn't Build
            Write-Host ">>> Tests Failed"
            return $false
        }

        Write-Host "   - Tests Succeded"
        return $true
    } catch  {
        # Didn't Build
        Write-Host ">>> Tests Failed"
        return $false
    }
}


function DotNet-BuildRunIntegrationTests {
    try {

        Write-Host " * Unit Tests and Integration Tests"    
        dotnet test --configuration Release --no-build --no-restore
        if(!$?) {
            # Didn't Build
            Write-Host ">>> Tests Failed"
            return $false;
        }

        Write-Host "   - Tests Succeded"
        return $true
    } catch  {
        # Didn't Build
        Write-Host ">>> Tests Failed"
        return $false
    }
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

    Write-Host "Building Source in $srcFolder"

    $buildOk = DotNet-BuildClean
    if($buildOk -eq $true) {
        $buildOk = DotNet-BuildRestore
        if($buildOk -eq $true) {
            $buildOk = DotNet-Build
            if($buildOk -eq $true) {
                if($runTests -eq $true) {
                    if($includeIntegrationTests -eq $false) {
	                    if($IsLinux -eq $true) {
                            $buildOk = DotNet-BuildRunUnitTestsLinux
                        } else {
                            $buildOk = DotNet-BuildRunUnitTestsWindows
                        }
                    }
                    else {
                        $buildOk =  DotNet-BuildRunIntegrationTests
                    }
            }
        }
    }

    # Restore the original path after any build.
    Set-Location -Path $originalPath

    return $buildOk
}

Export-ModuleMember -Function DotNet-BuildSolution
