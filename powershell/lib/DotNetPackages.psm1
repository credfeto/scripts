
function ToArray
{
  begin
  {
    $output = @();
  }
  process
  {
    $output += $_;
  }
  end
  {
    return ,$output;
  }
}

function DotNetPackages-Get {
param (
    [string]$srcFolder
)
    $packages = @()

    $projects = Get-ChildItem -Path $srcFolder -Filter *.csproj -Recurse

    ForEach($project in $projects) {
        [string]$projectFileName = $project.FullName
        Write-Host $projectFileName

        $xml = [xml](Get-Content $projectFileName)
        
        $projectXml = $xml | Select-Xml -XPath "Project"
        if($projectXml) {
            $sdk = $projectXml[0].Node.Sdk
            if($sdk)
            {
                $sdkPackage = $sdk.Split("/")[0]
                
                if(!$packages -contains $sdkPackage) {
                    $packages += $sdkPackage
                }
            }
        }
        
        $packageReferences = $xml | Select-Xml -XPath "Project/ItemGroup/PackageReference"

        foreach($node in $packageReferences)
        {
            if($node.Node.Include)
            {
                $packageId = $node.Node.Include
                $packages += $packageId
            }
        }

    }

    return $packages | Sort-Object | Get-Unique | ToArray
}


Export-ModuleMember -Function DotNetPackages-Get