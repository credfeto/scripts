
function DotNet-BuildClean {
    try {
        Write-Output " * Cleaning"
        $result = dotnet clean --configuration=Release 
        if(!$?) {
            Write-Output ">>> Clean Failed"
            Write-Output $result
            return $false
        }
        
        Write-Output "   - Clean Succeded"

        return $true
    } catch  {
        Write-Output ">>> Clean Failed"
        return $false
    }
}

function DotNet-BuildRestore {
    try {
        Write-Output " * Restoring"
        dotnet restore
        if(!$?) {
            Write-Output ">>> Restore Failed"
            return $false
        }

        Write-Output "   - Restore Succeded"
        return $true
    } catch  {
        Write-Output ">>> Restore Failed"
        return $false
    }
}

function DotNet-Build {
    try {
        Write-Output " * Building"
        dotnet build --configuration=Release --no-restore -warnAsError
        if(!$?) {
            Write-Output ">>> Build Failed"
            
            return $false
        }

        Write-Output "   - Build Succeded"

        return $true
    } catch  {
        Write-Output ">>> Build Failed"
        return $false
    }
}

function DotNet-BuildRunUnitTestsLinux {
    try {
        Write-Output " * Unit Tests"
        dotnet test --configuration Release --no-build --no-restore --filter FullyQualifiedName\!~Integration
        if(!$?) {
            Write-Output ">>> Tests Failed"
            return $false
        }

        Write-Output "   - Tests Succeded"
        return $true
    } catch  {
        Write-Output ">>> Tests Failed"
        return $false
    }
}

function DotNet-BuildRunUnitTestsWindows {
    try {

        Write-Output " * Unit Tests"
        dotnet test --configuration Release --no-build --no-restore --filter FullyQualifiedName!~Integration
        if(!$?) {
            # Didn't Build
            Write-Output ">>> Tests Failed"
            return $false
        }

        Write-Output "   - Tests Succeded"
        return $true
    } catch  {
        # Didn't Build
        Write-Output ">>> Tests Failed"
        return $false
    }
}


function DotNet-BuildRunIntegrationTests {
    try {

        Write-Output " * Unit Tests and Integration Tests"    
        dotnet test --configuration Release --no-build --no-restore
        if(!$?) {
            # Didn't Build
            Write-Output ">>> Tests Failed"
            return $false;
        }

        Write-Output "   - Tests Succeded"
        return $true
    } catch  {
        # Didn't Build
        Write-Output ">>> Tests Failed"
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

    try
    {
        Write-Output "Building Source in $srcFolder"

        $buildOk = DotNet-BuildClean
        if($buildOk -eq $true) {
            $buildOk = DotNet-BuildRestore
            if($buildOk -eq $true) {
                $buildOk = DotNet-Build
                if($buildOk -eq $true) {
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
                }
            }
        }
        return $false
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
