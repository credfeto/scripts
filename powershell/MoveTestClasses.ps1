﻿$base = "D:\work\funfair-wallet-server\src\FunFair.FunWallet.Data.SqlServer"
$testBase = "D:\work\funfair-wallet-server\src\FunFair.FunWallet.Data.SqlServer.Tests.Integration"

$files = Get-ChildItem -Path $base -Filter "*.cs" -Recurse
$testFiles = Get-ChildItem -Path $testBase -Filter "*.cs" -Recurse

foreach($sourceFile in $files) {
    $sourceFileName = $sourceFile.Name
    $sourceFilePath = $sourceFile.FullName
    #Write-Host $sourceFileName
    #Write-Host $sourceFilePath

    $testFile = $sourceFileName.Replace(".cs", "Tests.cs");
    #Write-Host $testFile

    $found = $null
    foreach( $candidate in $testFiles ) {
        $candidateFileName = $candidate.Name
        if( $candidateFileName -eq $testFile ) {
            $found = $candidate
            #Write-Host $testFile
            break
        }
    }

    if($found -ne $null) {
        $moveFileName = $found.Name
        $movePath = $found.FullName
        $moveFolder = $found.FullName.SubString($testBase.Length).Replace($moveFileName, "").TrimEnd('\')
        $sourceFolder = $sourceFilePath.SubString($base.Length).Replace($sourceFileName, "").TrimEnd('\')

        if( $sourceFolder -ne $moveFolder ) {
            $targetFolder = $testBase + $sourceFolder
            Write-Host $targetFolder

            $folderExists = Test-Path -Path $targetFolder -PathType Container
            if( $folderExists -ne $true )
            {
                New-Item -Path $targetFolder -ItemType Directory              
            }

            Move-Item -Path $movePath -Destination $targetFolder
        }
        #Write-Host $sourceFolder
        #Write-Host $moveFileName
    }
}