param(
    [string] $server = $(throw "Server"),
    [string] $user = $(throw "User"),
    [string] $password = $(throw "Password"),
    [string] $database = $(throw "Database")
)

Remove-Module *
Set-StrictMode -Version 1

$InformationPreference = "Continue"
$ErrorActionPreference = "Stop"

$files = Get-ChildItem -Path . -Filter appsettings.json -Recurse
ForEach($file in $files) {
    $readFile = $file.FullName
    $folder = $file.Directory.FullName
    $projects = Get-ChildItem -Path $folder -Filter *.csproj
    if( !$projects) {
        Continue
    }
        
    $sourceProperties = Get-Content -Raw -Path $readFile | ConvertFrom-Json
    
    if( !$sourceProperties.DatabaseConfiguration.ConnectionString) {
        continue
    }
    
    $fileToUpdate = $readFile.Replace(".json", "-local.json")
    
    $updateFileExists = Test-Path -Path $fileToUpdate
    if($updateFileExists) {
        Write-Information "* Updating $fileToUpdate"
        $properties = Get-Content -Raw -Path $readFile | ConvertFrom-Json
    }
    else {
        Write-Information "* Creating $fileToUpdate"
        $properties = ConvertFrom-Json '{"DatabaseConfiguration": {"Provider":"","ConnectionString":""}}'
    }

    Write-Information "  - Setting DatabaseConfiguration:Provider"
    $properties.DatabaseConfiguration.Provider = "mssql"
    
    Write-Information "  - Setting DatabaseConfiguration:ConnectionString"
    $properties.DatabaseConfiguration.ConnectionString = "Database=$database;Server=$server;User ID=$user;Password=$password;Application Name=$database;Connection Timeout=60"

    $properties | ConvertTo-Json -Compress | Out-File -encoding ASCII $fileToUpdate

}