
function Project_ReOrderPropertyGroups {
param (
    $project
)
    $toRemove = @()
    
    $propertyGroups = $project.SelectNodes("PropertyGroup")
    foreach($propertyGroup in $propertyGroups) {
        $children = $propertyGroup.SelectNodes("*")
        $orderedChildren = @{}
        [bool]$replace = $true
        foreach($child in $children) {
            [string]$name = ($child.Name).ToString().ToUpper()
            if($name -eq "#COMMENT") {
                $replace = $false;
                Write-Information "SKIPPING GROUP AS Found Comment"
                Break
            }
            
            if($orderedChildren.Contains($name)) {
                $replace = $false;
                Write-Information "SKIPPING GROUP AS Found Duplicate item $name"
                Break
            }
            $orderedChildren.Add($name, $child)
        }
                      
        if($replace) {
            if($orderedChildren) {
                $propertyGroup.RemoveAll()
                foreach($entryKey in $orderedChildren.Keys | Sort-Object -CaseSensitive) {
                    $item = $orderedChildren[$entryKey]
                    $propertyGroup.AppendChild($item)
                }
            }
            else {
                $toRemove.Add($propertyGroup)
            }
        }
    }
    
    # remove any empty groups
    foreach($item in $toRemove) {
        [void]$project.RemoveChild($item)
    }
}

function Project_ReOrderIncludes {
param (
    $project
)

    $itemGroups = $project.SelectNodes("ItemGroup")
    
    $normalItems = @{}
    $privateItems = @{}
    $projectItems = @{}
    
    foreach($itemGroup in $itemGroups) {
        if($itemGroup.HasAttributes) {
            # Skip groups that have attributes
            Write-Information "Has Attributes"
            Continue
        }
    
        $toRemove = @()
              
        # Extract Package References
        $includes = $itemGroup.SelectNodes("PackageReference")
        if($includes.Count -ne 0) {
        
            foreach($include in $includes) {
            
                [string]$packageId = $include.GetAttribute("Include")
                [string]$private = $include.GetAttribute("PrivateAssets")
                $toRemove += $include
            
                if([string]::IsNullOrEmpty($private)) {
                    if(!$normalItems.Contains($packageId.ToUpper())) {
                        $normalItems.Add($packageId.ToUpper(), $include)
                    }
                }
                else {
                    if(!$privateItems.Contains($packageId.ToUpper())) {
                        $privateItems.Add($packageId.ToUpper(), $include)
                    }          
                }
            }
        }
        
        # Extract Project References
        $includes = $itemGroup.SelectNodes("ProjectReference")
        if($includes.Count -ne 0) {
        
            foreach($include in $includes) {
            
                [string]$projectPath = $include.GetAttribute("Include")
            
                $toRemove += $include
                if(!$projectItems.Contains($projectPath.ToUpper())) {
                    $projectItems.Add($projectPath.ToUpper(), $include)
                }
            }
        }
        
        # Folder Includes
        $includes = $itemGroup.SelectNodes("Folder")
        if($includes.Count -ne 0) {
            foreach($include in $includes) {
                $toRemove += $include
            }
        }
        
        # Remove items marked for deletion
        foreach($include in $toRemove) {
            [void]$itemGroup.RemoveChild($include)
        }
        
        # Remove Empty item Groups
        if($itemGroup.ChildNodes.Count -eq 0) {
            [void]$project.RemoveChild($itemGroup)
        } 
    }
  
    # Write References to projects
    if($projectItems.Count -ne 0) {
        $itemGroup = $data.CreateElement("ItemGroup")
        foreach($includeKey in $projectItems.Keys | Sort-Object -CaseSensitive ) {
            $include = $projectItems[$includeKey]
            $itemGroup.AppendChild($include)
        }
        $project.AppendChild($itemGroup)
    }
    
    # Write References that are not dev only dependencies
    if($normalItems.Count -ne 0) {
        $itemGroup = $data.CreateElement("ItemGroup")
        foreach($includeKey in $normalItems.Keys | Sort-Object -CaseSensitive ) {
            $include = $normalItems[$includeKey]
            $itemGroup.AppendChild($include)
        }
        $project.AppendChild($itemGroup)
    }
  
    # Write References that are dev only dependencies
    if($privateItems.Count -ne 0) {
        $itemGroup = $data.CreateElement("ItemGroup")
        foreach($includeKey in $privateItems.Keys | Sort-Object -CaseSensitive ) {
            $include = $privateItems[$includeKey]
            $itemGroup.AppendChild($include)
        }
        $project.AppendChild($itemGroup)
    }
}

function Project_Cleanup {
param (
    [string] $projectFile
    )
    
    $data = [xml](Get-Content $projectFile)
    
    $project = $data.SelectSingleNode("/Project")

    Project_ReOrderPropertyGroups -project $project
    Project_ReOrderIncludes -project $project
  
    $xws = new-object System.Xml.XmlWriterSettings
    $xws.Indent = $true
    $xws.IndentChars = "  "
    $xws.NewLineOnAttributes = $false
    $xws.OmitXmlDeclaration = $true
    
    $outputFile = $projectFile
    $data.Save([Xml.XmlWriter]::Create($outputFile, $xws))    
} 

Export-ModuleMember -Function Project_Cleanup