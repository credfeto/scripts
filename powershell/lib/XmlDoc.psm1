function XmlDoc_RemoveComments {  
param (
    [string] $sourceFolder = $(throw "XmlDoc_RemoveComments: sourceFolder not specified")
    )
    
    Write-Information "* Changing Removing XmlDoc Comments"
    Write-Information "  - Folder: $sourceFolder"

    [bool]$changed = $false
    $files = Get-ChildItem -Path $sourceFolder -Filter "*.cs" -Recurse
    ForEach($file in $files) {
        [string]$fileName = $file.FullName

        [string]$content = Get-Content -Path $fileName -Raw
        [string]$originalContent = $content
        [string]$updatedContent = $content

        [bool]$changedFile = $False
        
        [string[]] $lines = $content.Split("`n")
        
        [string[]] $target = @();
        ForEach($line in $lines) {
            if ($line.Trim().StartsWith("///")) {
                $changedFile = $true
                continue    
            }
            $target += ,$line
            
        }
        
        if($changedFile) {
            $updatedContent = $target -Join "`n"
            if($updatedContent -ne $originalContent) {
                $changed = $true
                Write-Information "* $fileName"
                Write-Information "   - Removed xml comments"
                $content = $updatedContent
            }
        }

        if($content -ne $originalContent) {
            [bool]$changed = $true
            Set-Content -Path $fileName -Value $content
        }
    }

    return $changed
}


Export-ModuleMember -Function XmlDoc_RemoveComments