function buildSolution($repoFolder) {

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

    # Should test here too?

    return $true;
}
