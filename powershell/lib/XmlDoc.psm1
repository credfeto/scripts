function XmlDoc_RemoveComments {  
param (
    [string] $sourceFolder = $(throw "XmlDoc_RemoveComments: sourceFolder not specified")
    )
    
    Log -message "* Removing XmlDoc Comments from C# files"
    Log -message "  - Folder: $sourceFolder"

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
                Log -message "* $fileName"
                Log -message "   - Removed xml comments"
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

function XmlDoc_DisableDocCommentForProject {
    param (
        [string] $projectPath = $(throw "XmlDoc_DisableDocCommentForProject: projectPath not specified")
        )
        
    [string[]]$warningsToRemove = @("1591", "CS1591")
        
    Log -message "* $fileName"
    $data = [xml](Get-Content $projectPath)
          
    [bool]$projectChanged = $false
    $propertyGroups = $data.SelectNodes("/Project/PropertyGroup")
    ForEach($propertyGroup in $propertyGroups) {
        $docNode = $propertyGroup.SelectSingleNode("DocumentationFile")
        if($docNode) {
            $propertyGroup.RemoveChild($docNode)
            $projectChanged = $true
            Log -message "   - Removed DocumentationFile"
        }
    }
  
    if($projectChanged) { 
        ForEach($propertyGroup in $propertyGroups) {
            $noWarning = $propertyGroup.SelectSingleNode("NoWarn")
            if($noWarning) {
                [string]$noWarnText = $noWarning.InnerText
                if($noWarnText) {
                    [string[]]$warnings = $noWarnText.Split(",")
                    [string[]]$filteredWarnings = $warnings | where { $_ -notin $warningsToRemove }
                    [string]$noWarnTextUpdated = $filteredWarnings -Join ","
                    
                    if($noWarnText -ne $noWarnTextUpdated) {
                        if($noWarnTextUpdated.length -eq 0) {
                            $noWarningParent = $noWarning.ParentNode
                            [void]$noWarningParent.RemoveChild($noWarning)
                            $newNoWarning = $data.CreateNode("element", "NoWarn", "")
                            [void]$noWarningParent.AppendChild($newNoWarning) 
                            
                        } else {
                            $noWarning.InnerText = $noWarnTextUpdated
                        }                        
                        $projectChanged = $true
                        Log -message "   - Updated NoWarn"
                        [bool]$projectChanged = $true
                    }
                }
            }   
        }
    }
  
    if($projectChanged) {
        $xws = new-object System.Xml.XmlWriterSettings
        $xws.Indent = $true
        $xws.IndentChars = "  "
        $xws.NewLineOnAttributes = $false
        $xws.OmitXmlDeclaration = $true
        $xws.Encoding = new-object System.Text.UTF8Encoding($false)
      
        $data.Save([Xml.XmlWriter]::Create($projectPath, $xws))
    }
  
    return $projectChanged      
}  

function XmlDoc_DisableDocComment {
param (
        [string] $sourceFolder = $(throw "XmlDoc_DisableDocComment: sourceFolder not specified")
    )
    
    Log -message "* Removing XmlDoc Comments from C# projects"
    Log -message "  - Folder: $sourceFolder"

    [bool]$changed = $false
    $files = Get-ChildItem -Path $sourceFolder -Filter "*.csproj" -Recurse
    ForEach($file in $files) {
        [string]$fileName = $file.FullName

        
        $projectChanged = XmlDoc_DisableDocCommentForProject -projectPath $fileName
        if($projectChanged) {
            $changed = $true
        }
    }
    
    return $changed
}


Export-ModuleMember -Function XmlDoc_RemoveComments
Export-ModuleMember -Function XmlDoc_DisableDocComment
