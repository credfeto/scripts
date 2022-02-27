

function getLabelColour{
param(
    [string]$name
    )

    [string]$lowerName = $name.ToLowerInvariant()

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
        [String] $prefix = $(throw "Labels_Update: prefix not specified"), 
        [String] $sourceFilesBase = $(throw "Labels_Update: sourceFilesBase not specified"), 
        [String] $labelerFileName = $(throw "Labels_Update: labelerFileName not specified"), 
        [String] $labelsFileName = $(throw "Labels_Update: labelsFileName not specified")
)

    $config = @(
        [pscustomobject]@{
            Name = "C#"
            Description = "C# Source Files"
            Colour = "db6baa"
            Paths = @( "./**/*.cs",
            "./**/*.csproj" )
            PathsExclude = @()
        },
        [pscustomobject]@{
            Name = "C# Project"
            Description = "C# Project Files"
            Colour = "db6baa"
            Paths = @( "./**/*.csproj" )
            PathsExclude = @()
        },
        [pscustomobject]@{
            Name = "C# Solution"
            Description = "C# Solutions"
            Colour = "db6baa"
            Paths = @( "./**/*.sln" )
            PathsExclude = @()
        },
        [pscustomobject]@{
            Name = "Powershell"
            Description = "Powershell Source Files"
            Colour = "23bc12"
            Paths = @( "./**/*.ps1",
            "./**/*.psm1" )
            PathsExclude = @()
        },
        [pscustomobject]@{
            Name = "SQL"
            Description = "SQL Source Files"
            Colour = "413cd1"
            Paths = @( "db/**/*",
            "./**/*.sql" )
            PathsExclude = @()
        },
        [pscustomobject]@{
            Name = "Solidity"
            Description = "Solidity Source Files"
            Colour = "413cd1"
            Paths = @( "./**/*.sol" )
            PathsExclude = @()
        },
        [pscustomobject]@{
            Name = "unit-tests"
            Description = "Unit test and integration test projects"
            Colour = "0e8a16"
            Paths = @( "src/*.Tests.*/**/*",
            "src/*.Tests.Integration.*/**/*",
            "src/*.Tests/**/*",
            "src/*.Tests.Integration/**/*" )
            PathsExclude = @()
        },
        [pscustomobject]@{
            Name = ".NET update"
            Description = "Update to .net global.json"
            Colour = "a870c9"
            Paths = @( "src/global.json" )
            PathsExclude = @()
        },
        [pscustomobject]@{
            Name = "Config Change"
            Description = "Configuration files changes"
            Colour = "d8bb50"
            Paths = @( "src/**/*.json" )
            PathsExclude = @( "src/global.json" )
        },
        [pscustomobject]@{
            Name = "Static Code Analysis Rules"
            Description = "Ruleset for static code analysis files"
            Colour = "00dead"
            Paths = @( "src/CodeAnalysis.ruleset" )
            PathsExclude = @()
        },
        [pscustomobject]@{
            Name = "Migration Script"
            Description = "SQL Migration scripts"
            Colour = "b680e5"
            Paths = @( "tools/MigrationScripts/**/*" )
            PathsExclude = @()
        },
        [pscustomobject]@{
            Name = "Legal Text"
            Description = "Legal text files"
            Colour = "facef0"
            Paths = @( "tools/LegalText/**/*" )
            PathsExclude = @()
        },
        [pscustomobject]@{
            Name = "Change Log"
            Description = "Changelog tracking file"
            Colour = "53fcd4"
            Paths = @( "CHANGELOG.md" )
            PathsExclude = @()
        },
        [pscustomobject]@{
            Name = "Read Me"
            Description = "Repository readme file"
            Colour = "5319e7"
            Paths = @( "README.md" )
            PathsExclude = @()
        },
        [pscustomobject]@{
            Name = "Setup"
            Description = "Setup instructions"
            Colour = "5319e7"
            Paths = @( "SETUP.md" )
            PathsExclude = @()
        },
        [pscustomobject]@{
            Name = "Markdown"
            Description = "Markdown files"
            Colour = "5319e7"
            Paths = @( "./**/*.md" )
            PathsExclude = @()
        },
        [pscustomobject]@{
            Name = "github-actions"
            Description = "Github actions workflow files"
            Colour = "e09cf4"
            Paths = @( ".github/workflows/*.yml" )
            PathsExclude = @()
        },
        [pscustomobject]@{
            Name = "Tech Debt"
            Description = "Technical debt"
            Colour = "30027a"
            Paths = @()
            PathsExclude = @()
        },
        [pscustomobject]@{
            Name = "auto-pr"
            Description = "Pull request created automatically"
            Colour = "0000aa"
            Paths = @()
            PathsExclude = @()
        },
        [pscustomobject]@{
            Name = "no-pr-activity"
            Description = "Pull Request has had no activity for a long time"
            Colour = "ffff00"
            Paths = @()
            PathsExclude = @()
        },
        [pscustomobject]@{
            Name = "!!! WAITING FOR CLIENT PR"
            Description = "Pull request needs a client pull request to be merged at the same time"
            Colour = "ffff00"
            Paths = @()
            PathsExclude = @()
        },
        [pscustomobject]@{
            Name = "!!! WAITING FOR WALLET PR"
            Description = "Pull request needs a wallet pull request to be merged at the same time"
            Colour = "ffff00"
            Paths = @()
            PathsExclude = @()
        },
        [pscustomobject]@{
            Name = "!!! WAITING FOR SERVER PR"
            Description = "Pull request needs a server pull request to be merged at the same time"
            Colour = "ffff00"
            Paths = @()
            PathsExclude = @()
        },
        [pscustomobject]@{
            Name = "!!! WAITING FOR QA SIGNOFF"
            Description = "Pull request needs a QA Signoff before it can be merged"
            Colour = "ffff00"
            Paths = @()
            PathsExclude = @()
        },
        [pscustomobject]@{
            Name = "!!! WAITING FOR ETHEREUM PR"
            Description = "Pull request needs a server ethereum pull request to be merged at the same time"
            Colour = "ffff00"
            Paths = @()
            PathsExclude = @()
        },
        [pscustomobject]@{
            Name = "dependencies"
            Description = "Updates to dependencies"
            Colour = "0366d6"
            Paths = @()
            PathsExclude = @()
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
            Name = "DO NOT MERGE"
            Description = "This pull request should not be merged yey"
            Colour = "ff0000"
            Paths = @()
            PathsExclude = @()
        }
    )
    
    if($sourceFilesBase -ne $null) {
        Write-Information "Updating project files under $sourceFilesBase"
        $projects = Get-ChildItem -Path $sourceFilesBase -Directory

        Foreach($project in $projects) {
            $projectList = Get-ChildItem -Path $projects.FullName -Filter "*.csproj"
            if($projectList.Count -ne 0) {

                [string]$name = $project.Name

                [string]$labelName = $name
                if($name.StartsWith($prefix +".") -eq $true) {
                    [string]$labelName = $name.SubString($prefix.Length + 1)
                }

                [string]$colour = getLabelColour($name)

                $newLabel = [pscustomobject]@{
                    Name = $labelName
                    Description = "Changes in $name project"
                    Colour = $colour
                    Paths = @("src/$name/**/*")
                    PathsExclude = @()
                }
        
                Write-Information "+++ Adding Label $labelName"
                $config += $newLabel
            }
        }
    }


    $labeller = @()
    $labelsWithColour = @()

    $sortedConfig = $config | Sort-Object -Property Name

    ForEach($group in $config) {

        $groupName = $group.Name
        Write-Information "Adding group $groupName"
        
        if ($group.Paths)
        {
            Write-Information " - With Paths..."
            [bool]$first = $true
            [string]$all = ' - any: [ '
            
            $sortedPaths = $group.Paths
            $sortedPaths = $sortedPaths | sort

            Foreach ($mask in $sortedPaths)
            {
                if ($first -ne $true)
                {
                    $all += ", "
                }

                $first = $false
                $all += "'$mask'"
            }

            if ($group.PathsExclude)
            {
                Write-Information " - With Excluded Paths..."
                $sortedPaths = $group.PathsExclude
                $sortedPaths = $sortedPaths | sort

                Foreach ($mask in $sortedPaths)
                {
                    if ($first -ne $true)
                    {
                        $all += ", "
                    }

                    $first = $false
                    $all += "'!$mask'"
                }

            }

            $all += ' ]'

            if($first -ne $true) {
                Write-Information " - Adding Group with file match"
                $labeller += '"' + $group.Name + '":'
                $labeller += $all
            }
        }

        Write-Information " - Adding Colour Group"
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
    