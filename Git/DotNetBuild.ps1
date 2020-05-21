function buildSolution($repoFolder, $runTests = $true, $includeIntegrationTests = $false) {

    $srcFolder = Join-Path -Path $repoFolder -ChildPath "src"
    Set-Location $srcFolder

    Write-Host "Building Source in $srcFolder"
    Write-Host " * Cleaning"
    dotnet clean --configuration=Release 
    if(!$?) {
        # Didn't Build
        return $false;
    }

    Write-Host " * Restoring"
    dotnet restore
    if(!$?) {
        # Didn't Build
        return $false;
    }

    Write-Host " * Building"
    dotnet build --configuration=Release --no-restore -warnAsError
    if(!$?) {
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
                    return $false;
                }
            }
            else {
                Write-Host " * Unit Tests and Integration Tests"    
                dotnet test --configuration Release --no-build --no-restore
                if(!$?) {
                    # Didn't Build
                    return $false;
                }
            }
         } catch  {
            # Didn't Build
            return $false;
        }
    }

    return $true;
}
