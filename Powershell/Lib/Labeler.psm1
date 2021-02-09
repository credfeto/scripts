

function getLabelColour($name) {

    $lowerName = $name.ToLowerInvariant()

    if($lowerName.EndsWith(".tests")) {
        return "0e8a16"
    }
    if($lowerName.Contains(".tests.")) {
        return "0e8a16"
    }

    if($lowerName.EndsWith(".mocks")) {
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
            Description="C# Source Files"
            Colour="db6baa"
            Paths = @( "src/**/*.cs",
                       "src/**/*.csproj" )
        },
        [pscustomobject]@{
            Name="Powershell"
            Description="Powershell Source Files"
            Colour="23bc12"
            Paths = @( "**/*.ps1",
                       "**/*.psm1" )
        },
        [pscustomobject]@{
            Name="SQL"
            Description="SQL Source Files"
            Colour="413cd1"
            Paths = @( "db/**/*",
                       "tools/**/*.sql" )

        },
        [pscustomobject]@{
            Name="Solidity"
            Description="Solidity Source Files"
            Colour="413cd1"
            Paths = @( "src/**/*.sol" )
        },
        [pscustomobject]@{
            Name="unit-tests"
            Description="Unit test and integration test projects"
            Colour="0e8a16"
            Paths = @( "src/*.Tests.*/**/*",
                       "src/*.Tests.Integration.*/**/*",
                       "src/*.Tests/**/*"
                       "src/*.Tests.Integration/**/*" )
        },
        [pscustomobject]@{
            Name=".NET update"
            Description="Update to .net global.json"
            Colour="a870c9"
            Paths = @( "src/global.json" )
        },
        [pscustomobject]@{
            Name="Config Change"
            Description="Configuration files changes"
            Colour="d8bb50"
            Paths = @( "src/**/*.json" )
        },
        [pscustomobject]@{
            Name="Static Code Analysis Rules"
            Description="Ruleset for static code analysis files"
            Colour="00dead"
            Paths = @( "src/CodeAnalysis.ruleset" )
        },
        [pscustomobject]@{
            Name="Migration Script"
            Description="SQL Migration scripts"
            Colour="b680e5"
            Paths = @( "tools/MigrationScripts/**/*" )
        },
        [pscustomobject]@{
            Name="Legal Text"
            Description="Legal text files"
            Colour="facef0"
            Paths = @( "tools/LegalText/**/*" )
        },
        [pscustomobject]@{
            Name="Change Log"
            Description="Changelog tracking file"
            Colour="53fcd4"
            Paths = @( "CHANGELOG.md" )
        },
        [pscustomobject]@{
            Name="Read Me"
            Description="Repository readme file"
            Colour="5319e7"
            Paths = @( "README.md" )
        },
        [pscustomobject]@{
            Name="Setup"
            Description="Setup instructions"
            Colour="5319e7"
            Paths = @( "SETUP.md" )
        },
        [pscustomobject]@{
            Name="github-actions"
            Description="Github actions workflow files"
            Colour="e09cf4"
            Paths = @( ".github/workflows/*.yml" )
        },
        [pscustomobject]@{
            Name="Tech Debt"
            Description="Technical debt"
            Colour="30027a"
            Paths = @()
        },
        [pscustomobject]@{
            Name="auto-pr"
            Description="Pull request created automatically"
            Colour="0000aa"
            Paths = @()
        },
        [pscustomobject]@{
            Name="no-pr-activity"
            Description="Pull Request has had no activity for a long time"
            Colour="ffff00"
            Paths = @()
        },
        [pscustomobject]@{
            Name="!!! WAITING FOR CLIENT PR"
            Description="Pull request needs a client pull request to be merged at the same time"
            Colour="ffff00"
            Paths = @()
        },
        [pscustomobject]@{
            Name="!!! WAITING FOR WALLET PR"
            Description="Pull request needs a wallet pull request to be merged at the same time"
            Colour="ffff00"
            Paths = @()
        },
        [pscustomobject]@{
            Name="!!! WAITING FOR SERVER PR"
            Description="Pull request needs a server pull request to be merged at the same time"
            Colour="ffff00"
            Paths = @()
        },
        [pscustomobject]@{
            Name="!!! WAITING FOR QA SIGNOFF"
            Description="Pull request needs a QA Signoff before it can be merged"
            Colour="ffff00"
            Paths = @()
        },
        [pscustomobject]@{
            Name="dependencies"
            Description="Updates to dependencies"
            Colour="0366d6"
            Paths = @()
        },
        [pscustomobject]@{
            Name="dotnet"
            Description="Dotnet package updates"
            Colour="db6baa"
            Paths = @()
        },
        [pscustomobject]@{
            Name="npm"
            Description="npm package upate"
            Colour="e99695"
            Paths = @()
        },
        [pscustomobject]@{
            Name="DO NOT MERGE"
            Description="This pull request should not be merged yey"
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
                                Description="Changes in $name project"
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

        $labelsWithColour += ' - name: "' + $group.Name + '"'
        $labelsWithColour += '   color: "' + $group.Colour + '"'
        if($group.Description -ne $null) {
            $labelsWithColour += '   description: "' + $group.Description + '"'
        }
        $labelsWithColour += ''

    }


    Set-Content -Path $labelerFileName -Value $labeller
    Set-Content -Path $labelsFileName -Value $labelsWithColour
}


Export-ModuleMember -Function Labels_Update
    