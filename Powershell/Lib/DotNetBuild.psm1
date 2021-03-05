
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
        dotnet restore -nodeReuse:False
        if(!$?) {
            Write-Information ">>> Restore Failed"
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
        dotnet build --configuration=Release --no-restore -warnAsError -nodeReuse:False
        if(!$?) {
            Write-Information ">>> Build Failed"
            
            return $false
        }

        Write-Information "   - Build Succeded"

        return $true
    } catch  {
        Write-Information ">>> Build Failed"
        return $false
    }
}

function DotNet-BuildRunUnitTestsLinux {
    try {
        Write-Information " * Unit Tests"
        dotnet test --configuration Release --no-build --no-restore -nodeReuse:False --filter FullyQualifiedName\!~Integration
        if(!$?) {
            Write-Information ">>> Tests Failed"
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
        dotnet test --configuration Release --no-build --no-restore -nodeReuse:False --filter FullyQualifiedName!~Integration
        if(!$?) {
            # Didn't Build
            Write-Information ">>> Tests Failed"
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


function DotNet-BuildRunIntegrationTests {
    try {

        Write-Information " * Unit Tests and Integration Tests"    
        dotnet test --configuration Release --no-build --no-restore -nodeReuse:False
        if(!$?) {
            # Didn't Build
            Write-Information ">>> Tests Failed"
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
