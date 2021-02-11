<#
 .Synopsis
  Updates the global.json file

 .Description
  Updates the global.json file

 .Parameter sourceFileName
  The source filename
 .Parameter targetFileName
  The file to write
#>
function GlobalJson_Update
{
    param(
        [String] $sourceFileName,
        [String] $targetFileName
    )
    $targetFreezeFileName = $targetFileName + ".freeze"
    $trgFreexeExists = Test-Path -Path $targetFreezeFileName
    if ($trgFreexeExists -eq $true)
    {
        # no source to update
        Write-Information "* no global.json is frozen in target"
        return $false
    }

    $srcExists = Test-Path -Path $sourceFileName
    if ($srcExists -eq $false)
    {
        # no source to update
        Write-Information "* no global.json in template"
        return $false
    }

    $srcContent = Get-Content $sourceFileName -Raw
    $srcGlobal = $srcContent | ConvertFrom-Json

    $trgExists = Test-Path -Path $targetFileName
    if ($trgExists -eq $true)
    {

        $trgContent = Get-Content $targetFileName -Raw

        if ($srcContent -eq $trgContent)
        {
            Write-Information "* target global.json same as source"
            return $false
        }

        $trgGlobal = $trgContent | ConvertFrom-Json

        $sourceVersion = $srcGlobal.sdk.version
        $targetVersion = $trgGlobal.sdk.version
        Write-Information "Source Version: $srcVersion"
        Write-Information "Target Version: $trgVersion"

        if ($trgGlobal.sdk.version -gt $srcGlobal.sdk.version)
        {
            Write-Information "* Target global.json specifies a newer version of .net"
            return $false
        }
    }
    else
    {
        Write-Information "Target global.json does not exist"
    }

    Set-Content -Path $targetFileName -Value $labelsWithColour
    return $true
}

Export-ModuleMember -Function GlobalJson_Update