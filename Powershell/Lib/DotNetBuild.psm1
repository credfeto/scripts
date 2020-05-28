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
    Write-Host " * Cleaning"
    dotnet clean --configuration=Release 
    if(!$?) {
        # Didn't Build
        Write-Host ">>> Clean Failed"
        return $false;
    }

    Write-Host " * Restoring"
    dotnet restore
    if(!$?) {
        # Didn't Build
        Write-Host ">>> Restore Failed"
        return $false;
    }

    Write-Host " * Building"
    dotnet build --configuration=Release --no-restore -warnAsError
    if(!$?) {
        Write-Host ">>> Build Failed"
        # Didn't Build
        return $false;
    }

    if($runTests -eq $true) {
        try
        {
            if($includeIntegrationTests -eq $false) {
                Write-Host " * Unit Tests"    
                dotnet test --configuration Release --no-build --no-restore --filter FullyQualifiedName!~Integration
                if(!$?) {
                    # Didn't Build
                    Write-Host ">>> Tests Failed"
                    return $false;
                }
            }
            else {
                Write-Host " * Unit Tests and Integration Tests"    
                dotnet test --configuration Release --no-build --no-restore
                if(!$?) {
                    # Didn't Build
                    Write-Host ">>> Tests Failed"
                    return $false;
                }
            }
         } catch  {
            # Didn't Build
            Write-Host ">>> Tests Failed"
            return $false;
        }
    }

    return $true;
}

Export-ModuleMember -Function DotNet-BuildSolution
