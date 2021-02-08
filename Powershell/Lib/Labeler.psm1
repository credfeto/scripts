

function getLabelColour($name) {

    $lowerName = $name.ToLowerInvariant()

    if($lowerName.EndsWith(".tests")) {
        return "0e8a16"
    }
    if($lowerName.Contains(".tests.")) {
        return "0e8a16"
    }

    return "96f7d2"
}

<#
 .Synopsis
  Updates the labels config files

 .Description
  Updates the labels config files

 .Parameter prefix
  The project prefix
 .Parameter sourceFilesBase
  The source files location
 .Parameter labelerFileName
  Location of .github/labeler.yml
 .Parameter sourceFilesBase
  Location of .github/labels.yml

#>
function Labels_Update {
param(
        [String] $prefix, 
        [String] $sourceFilesBase, 
        [String] $labelerFileName, 
        [String] $labelsFileName
)

    $config = @(
        [pscustomobject]@{
            Name="C#"
            Colour="db6baa"
            Paths = @( "src/**/*.cs",
                       "src/**/*.csproj" )
        },
        [pscustomobject]@{
            Name="Powershell"
            Colour="23bc12"
            Paths = @( "**/*.ps1",
                       "**/*.psm1" )
        },
        [pscustomobject]@{
            Name="SQL"
            Colour="413cd1"
            Paths = @( "db/**/*",
                       "tools/**/*.sql" )

        },
        [pscustomobject]@{
            Name="Solidity"
            Colour="413cd1"
            Paths = @( "src/**/*.sol" )
        },
        [pscustomobject]@{
            Name="unit-tests"
            Colour="0e8a16"
            Paths = @( "src/*.Tests.*/**/*",
                       "src/*.Tests.Integration.*/**/*",
                       "src/*.Tests/**/*"
                       "src/*.Tests.Integration/**/*" )
        },
        [pscustomobject]@{
            Name=".NET update"
            Colour="a870c9"
            Paths = @( "src/global.json" )
        },
        [pscustomobject]@{
            Name="Config Change"
            Colour="d8bb50"
            Paths = @( "src/**/*.json" )
        },
        [pscustomobject]@{
            Name="Static Code Analysis Rules"
            Colour="00dead"
            Paths = @( "src/CodeAnalysis.ruleset" )
        },
        [pscustomobject]@{
            Name="Migration Script"
            Colour="b680e5"
            Paths = @( "tools/MigrationScripts/**/*" )
        },
        [pscustomobject]@{
            Name="Legal Text"
            Colour="facef0"
            Paths = @( "tools/LegalText/**/*" )
        },
        [pscustomobject]@{
            Name="Change Log"
            Colour="53fcd4"
            Paths = @( "CHANGELOG.md" )
        },
        [pscustomobject]@{
            Name="Read Me"
            Colour="5319e7"
            Paths = @( "README.md" )
        },
        [pscustomobject]@{
            Name="Setup"
            Colour="5319e7"
            Paths = @( "SETUP.md" )
        },
        [pscustomobject]@{
            Name="github-actions"
            Colour="e09cf4"
            Paths = @( ".github/workflows/*.yml" )
        },
        [pscustomobject]@{
            Name="Tech Debt"
            Colour="30027a"
            Paths = @()
        },
        [pscustomobject]@{
            Name="auto-pr"
            Colour="0000aa"
            Paths = @()
        },
        [pscustomobject]@{
            Name=".NET Update"
            Colour="a870c9"
            Paths = @()
        },
        [pscustomobject]@{
            Name="no-pr-activity"
            Colour="ffff00"
            Paths = @()
        },
        [pscustomobject]@{
            Name="!!! WAITING FOR CLIENT PR"
            Colour="ffff00"
            Paths = @()
        },
        [pscustomobject]@{
            Name="!!! WAITING FOR WALLET PR"
            Colour="ffff00"
            Paths = @()
        },
        [pscustomobject]@{
            Name="!!! WAITING FOR SERVER PR"
            Colour="ffff00"
            Paths = @()
        },
        [pscustomobject]@{
            Name="!!! WAITING FOR QA SIGNOFF"
            Colour="ffff00"
            Paths = @()
        },
        [pscustomobject]@{
            Name="dependencies"
            Colour="0366d6"
            Paths = @()
        },
        [pscustomobject]@{
            Name="dotnet"
            Colour="db6baa"
            Paths = @()
        },
        [pscustomobject]@{
            Name="npm"
            Colour="e99695"
            Paths = @()
        },
        [pscustomobject]@{
            Name="DO NOT MERGE"
            Colour="ff0000"
            Paths = @()
        }
    )
    
    if($sourceFilesBase -ne $null) {
        Write-Information "Updating project files under $sourceFilesBase"
        $projects = Get-ChildItem -Path $sourceFilesBase -Directory

        Foreach($project in $projects) {
            $projectList = Get-ChildItem -Path $projects.FullName -Filter "*.csproj"
            if($projectList.Count -ne 0) {

                $name = $project.Name

                $labelName = $name
                if($name.StartsWith($prefix +".") -eq $true) {
                    $labelName = $name.SubString($prefix.Length + 1)
                }

                $colour = getLabelColour($name)

                $newLabel = [pscustomobject]@{
                                Name=$labelName
                                Colour=$colour
                                Paths = @("src/$name/**/*")
                            }
        
                $config += $newLabel
            }
        }
    }


    $labeller = @()
    $labelsWithColour = @()


    ForEach($group in $config) {

        if($group.Paths) {

            $labeller += '"' + $group.Name + '":'
            Foreach($mask in $group.Paths) {

                $labeller += ' - ' + $mask
            }

            $labeller += ''
        }

        $labelsWithColour += ' - name: "' + $group.Name + '":'
        $labelsWithColour += '   color: "' + $group.Colour + '"'
        $labelsWithColour += ''

    }


    Set-Content -Path $labelerFileName -Value $labeller
    Set-Content -Path $labelsFileName -Value $labelsWithColour
}


Export-ModuleMember -Function Labels_Update
    