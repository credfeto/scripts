function Tracking_Read($fileName) {
    $content = @{}

    $srcExists = Test-Path -Path $fileName
    if($srcExists -eq $true) {

        $obj = Get-Content $srcPath| Out-String | ConvertFrom-Json

        $obj.psobject.properties | Foreach { $content[$_.Name] = $_.Value }
    }

    return $content
}

function Tracking_Get {
param(
    [string] $basePath, 
    [string] $repo
    )

    $srcPath = Join-Path -Path $basePath -ChildPath "tracking.json"

    $content = Tracking_Read -fileName $srcPath


    if($content.Contains($repo) -eq $true) {
        return $content[$repo]
    }
        
    return $null
}

function Tracking_Set {
param(
    [string] $basePath, 
    [string] $repo,
    [string] $value
    )

    $srcPath = Join-Path -Path $basePath -ChildPath "tracking.json"

    $content = Tracking_Read -fileName $srcPath

    $content[$repo] = $value;

    $fileContent = $content | ConvertTo-Json

    Set-Content -Path $srcPath -Value $fileContent
}


Export-ModuleMember -Function Tracking_Get
Export-ModuleMember -Function Tracking_Set