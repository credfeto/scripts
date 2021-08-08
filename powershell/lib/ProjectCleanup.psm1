
function Project_Cleanup {
param (
    [string] $projectFile
    )
    
  $data = [xml](Get-Content $projectFile)
  
  $project = $data.SelectSingleNode("/Project")
  $itemGroups = $data.SelectNodes("/Project/ItemGroup")

  $normalItems = @{}
  $privateItems = @{}
  $projectItems = @{}

  foreach($itemGroup in $itemGroups) {
    if($itemGroup.HasAttributes) {
        # Skip groups that have attributes
        Write-Output "Has Attributes"
        Continue
    }
    
    $toRemove = @()
          
    # Extract Package References
    $includes = $itemGroup.SelectNodes("PackageReference")
    if($includes.Count -ne 0) {
    
      foreach($include in $includes) {
        
        $packageId = $include.GetAttribute("Include")
        $private = $include.GetAttribute("PrivateAssets")
        $toRemove += $include
        
        if([string]::IsNullOrEmpty($private)) {
          $normalItems.Add($packageId.ToUpper(), $include);
        }
        else {
          $privateItems.Add($packageId.ToUpper(), $include);          
        }
      }
    }

    # Extract Project References
    $includes = $itemGroup.SelectNodes("ProjectReference")
    if($includes.Count -ne 0) {
    
      foreach($include in $includes) {
        
        $projectPath = $include.GetAttribute("Include")
        
        $toRemove += $include
        $projectItems.Add($projectPath.ToUpper(), $include);
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
  
  $xws = new-object System.Xml.XmlWriterSettings
  $xws.Indent = $true
  $xws.IndentChars = "  "
  $xws.NewLineOnAttributes = $false
  $xws.OmitXmlDeclaration = true
  
  $outputFile = $projectFile
  $data.Save([Xml.XmlWriter]::Create($outputFile, $xws))    
} 

Export-ModuleMember -Function Project_Cleanup