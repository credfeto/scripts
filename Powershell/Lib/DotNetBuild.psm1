
function DotNet-BuildClean {
    try {
        Write-Host " * Cleaning"
        dotnet clean --configuration=Release 
        if(!$?) {
            Write-Host ">>> Clean Failed"
            return $False
        }

        return $true
    } catch  {
        Write-Host ">>> Clean Failed"
        return $False
    }
}

function DotNet-BuildRestore {
    try {
        Write-Host " * Restoring"
        dotnet restore
        if(!$?) {
            Write-Host ">>> Restore Failed"
            return $False
        }

        return $true
    } catch  {
        Write-Host ">>> Restore Failed"
        return $False
    }
}

function DotNet-Build {
    try {
        Write-Host " * Building"
        dotnet build --configuration=Release --no-restore -warnAsError
        if(!$?) {
            Write-Host ">>> Build Failed"
            
            return $False
        }

        return $true
    } catch  {
        Write-Host ">>> Build Failed"
        return $False
    }
}

function DotNet-BuildRunUnitTestsLinux {
    try {
        Write-Host " * Unit Tests"
        dotnet test --configuration Release --no-build --no-restore --filter FullyQualifiedName\!~Integration
        if(!$?) {
            Write-Host ">>> Tests Failed"
            return $False
        }

        return $true
    } catch  {
        Write-Host ">>> Tests Failed"
        return $False
    }
}

function DotNet-BuildRunUnitTestsWindows {
    try {

        Write-Host " * Unit Tests"
        dotnet test --configuration Release --no-build --no-restore --filter FullyQualifiedName!~Integration
        if(!$?) {
            # Didn't Build
            Write-Host ">>> Tests Failed"
            return $False
        }

        return $true
    } catch  {
        # Didn't Build
        Write-Host ">>> Tests Failed"
        return $False
    }
}


function DotNet-BuildRunIntegrationTests {
    try {

        Write-Host " * Unit Tests and Integration Tests"    
        dotnet test --configuration Release --no-build --no-restore
        if(!$?) {
            # Didn't Build
            Write-Host ">>> Tests Failed"
            return $False;
        }

        return $true
    } catch  {
        # Didn't Build
        Write-Host ">>> Tests Failed"
        return $False
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

    
    Set-Location $srcFolder

    Write-Host "Building Source in $srcFolder"

    $buildOk = DotNet-BuildClean
    if($buildOk -ne $true) {
        return $buildOk
    }

    $buildOk = DotNet-BuildRestore
    if($buildOk -ne $true) {
        return $buildOk
    }


    $buildOk = DotNet-Build
    if($buildOk -ne $true) {
        return $buildOk
    }

    if($runTests -eq $true) {
        if($includeIntegrationTests -eq $false) {
	        if($IsLinux -eq $true) {
                return DotNet-BuildRunUnitTestsLinux
            } else {
                return DotNet-BuildRunUnitTestsWindows
            }
        }
        else {
            return DotNet-BuildRunIntegrationTests
        }
    }

    return $true
}

Export-ModuleMember -Function DotNet-BuildSolution
