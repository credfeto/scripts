
function dotNetDependabotTemplate {
    
    return "
- package-ecosystem: nuget
  directory: ""/""
  schedule:
    interval: daily
    time: ""03:00""
    timezone: ""Europe/London""
  open-pull-requests-limit: 99
  reviewers:
  - credfeto
  assignees:
  - credfeto
  allow:
  - dependency-type: all
  ignore:
  - dependency-name: ""AWSSDK.*""
  - dependency-name: ""codecracker.CSharp""
  - dependency-name: ""Coverlet.*""
  - dependency-name: ""FunFair.*""
  - dependency-name: ""Microsoft.AspNetCore.*""
  - dependency-name: ""Microsoft.CodeAnalysis.*""
  - dependency-name: ""Microsoft.Extensions.*""
  - dependency-name: ""NuGet.*""
  - dependency-name: ""Swashbuckle.*""
  - dependency-name: ""AsyncFixer""
  - dependency-name: ""Castle.Core""
  - dependency-name: ""Cryptography.ECDSA.Secp256K1""
  - dependency-name: ""Dapper""
  - dependency-name: ""DisableDateTimeNow""
  - dependency-name: ""Discord.Net""
  - dependency-name: ""dotnetstandard-bip39""
  - dependency-name: ""FluentValidation.AspNetCore""
  - dependency-name: ""HexMate""
  - dependency-name: ""HtmlAgilityPack""
  - dependency-name: ""IPAddressRange""
  - dependency-name: ""Jetbrains.Annotations""
  - dependency-name: ""LibGit2Sharp""
  - dependency-name: ""Meziantou.Analyzer""
  - dependency-name: ""MaxMind.GeoIP2""
  - dependency-name: ""MaxMind.MinFraud""
  - dependency-name: ""Microsoft.ApplicationInsights.AspNetCore""
  - dependency-name: ""Microsoft.NET.Test.Sdk""
  - dependency-name: ""Microsoft.VisualStudio.Threading.Analyzers""
  - dependency-name: ""NBitcoin""
  - dependency-name: ""Newtonsoft.Json""
  - dependency-name: ""Npgsql""
  - dependency-name: ""NSubstitute""
  - dependency-name: ""NSubstitute.Analyzers.CSharp""
  - dependency-name: ""Nullable.Extended.Analyzer""
  - dependency-name: ""Octopus.Client""
  - dependency-name: ""Philips.CodeAnalysis.DuplicateCodeAnalyzer""
  - dependency-name: ""Philips.CodeAnalysis.MaintainabilityAnalyzers""
  - dependency-name: ""Portable.BouncyCastle""
  - dependency-name: ""Profanity.Detector""
  - dependency-name: ""Roslynator.Analyzers""
  - dependency-name: ""ScottPlot""
  - dependency-name: ""SecurityCodeScan.*""
  - dependency-name: ""SmartAnalyzers.CSharpExtensions.Annotations""
  - dependency-name: ""SonarAnalyzer.CSharp""
  - dependency-name: ""SourceLink.Create.CommandLine""
  - dependency-name: ""TeamCity.VSTest.TestAdapter""
  - dependency-name: ""ToStringWithoutOverrideAnalyzer""
  - dependency-name: ""TwitchLib.Api""
  - dependency-name: ""UAParser""
  - dependency-name: ""xunit""
  - dependency-name: ""xunit.analyzers""
  - dependency-name: ""xunit.runner.visualstudio""
  - dependency-name: ""Yoti""
  commit-message:
    prefix: ""[FF-1429]""
  rebase-strategy: ""auto""
  labels:
  - ""dotnet""
  - ""dependencies""
  - ""Changelog Not Required""    
"
}

function javascriptDependabotTemplate {
param([string]$path)
    return "
- package-ecosystem: npm
  directory: ""$path""
  schedule:
    interval: daily
    time: ""03:00""
    timezone: ""Europe/London""
  open-pull-requests-limit: 2
  reviewers:
  - credfeto
  assignees:
  - credfeto
  allow:
  - dependency-type: all
  commit-message:
    prefix: ""[FF-1429]""
  rebase-strategy: ""auto""
  versioning-strategy: increase-if-necessary
  labels:
  - ""npm""
  - ""dependencies""
  - ""Changelog Not Required""
"
}

function dockerDependabotTemplate {
    return "
- package-ecosystem: docker
  directory: ""/""
  schedule:
    interval: daily
    time: ""03:00""
    timezone: ""Europe/London""
  open-pull-requests-limit: 99
  reviewers:
  - credfeto
  assignees:
  - credfeto
  allow:
  - dependency-type: all
  commit-message:
    prefix: ""[FF-1429]""
  rebase-strategy: ""auto""
  labels:
  - ""docker""
  - ""dependencies""
  - ""Changelog Not Required""
"
}

function githubActionsDependabotTemplate {
    return "
- package-ecosystem: github-actions
  directory: ""/""
  schedule:
    interval: daily
    time: ""03:00""
    timezone: ""Europe/London""
  open-pull-requests-limit: 99
  reviewers:
  - credfeto
  assignees:
  - credfeto
  allow:
  - dependency-type: all
  commit-message:
    prefix: ""[FF-1429]""
  rebase-strategy: ""auto""
  labels:
  - ""github-actions""
  - ""dependencies""
  - ""Changelog Not Required""
"
}

function pythonDependabotTemplate {
    return "
- package-ecosystem: pip
  directory: ""/""
  schedule:
    interval: daily
    time: ""03:00""
    timezone: ""Europe/London""
  open-pull-requests-limit: 99
  reviewers:
  - credfeto
  assignees:
  - credfeto
  allow:
  - dependency-type: all
  commit-message:
    prefix: ""[FF-1429]""
  rebase-strategy: ""auto""
  labels:
  - ""python""
  - ""dependencies""
  - ""Changelog Not Required""
"
}

function githubSubmodulesDependabotTemplate {
    return "
- package-ecosystem: gitsubmodule
  directory: ""/""
  schedule:
    interval: weekly
  open-pull-requests-limit: 99
  reviewers:
  - credfeto
  assignees:
  - credfeto
  commit-message:
    prefix: ""[FF-1429]""
  rebase-strategy: ""auto""
  labels:
  - ""submodule""
  - ""dependencies""
  - ""Changelog Not Required""
"
}

function makePath($Path, $ChildPath)
{
    [string]$ChildPath = convertToOsPath -path $ChildPath

    return [System.IO.Path]::Combine($Path, $ChildPath)
}

function convertToOsPath($path)
{
    if ($IsLinux -eq $true)
    {
        return $path.Replace("\", "/")
    }

    return $path
}


function Dependabot-BuildConfig {
param(
    [string] $configFileName = $(throw "Dependabot-BuildConfig: configFileName not specified"),
    [string] $repoRoot = $(throw "Dependabot-BuildConfig: repoRoot not specified"),
    [bool] $updateGitHubActions = $(throw "Dependabot-BuildConfig: updateGitHubActions not specified"),
    [bool] $hasSubModules = $(throw "Dependabot-BuildConfig: hasSubModules not specified")
    )

    Write-Information "Building Dependabot Config:"
    [string]$trgContent = "version: 2
updates:
"
    
    [string]$newline = "`r`n"

    if($hasSubModules)
    {
        Write-Information " --> Adding Git Submodules"
        [string]$templateContent = githubSubmodulesDependabotTemplate
        [string]$trgContent = $trgContent.Trim() + $newline + $newline
        [string]$trgContent = $trgContent + $templateContent
    }
    else {
        Write-Information " --> NO Git Submodules"
    }

    $files = Get-ChildItem -Path $repoRoot -Filter *.csproj -Recurse
    if($files) {
        Write-Information " --> Adding .NET"
        [string]$templateContent = dotNetDependabotTemplate
        [string]$trgContent = $trgContent.Trim() + $newline + $newline
        [string]$trgContent = $trgContent + $templateContent
    }
    else {
        Write-Information " --> NO .NET"
    }
    
    $files = Get-ChildItem -Path $repoRoot -Filter 'package.json' -Recurse
    if($files) {        
        foreach($file in $files) {
            [string]$dirName = $file.Directory.FullName
            [string]$path = $dirName.SubString($repoRoot.length)
            
            Write-Information " --> Adding Javascript: $path"            
            [string]$templateContent = javascriptDependabotTemplate -path $path 
            [string]$trgContent = $trgContent.Trim() + $newline + $newline
            [string]$trgContent = $trgContent + $templateContent
        }
    }
    else {
        Write-Information " --> NO Javascript"
    }
    
    $files = Get-ChildItem -Path $repoRoot -Filter 'Dockerfile' -Recurse
    if($files) {
        Write-Information " --> Adding Docker"
        [string]$templateContent = dockerDependabotTemplate
        [string]$trgContent = $trgContent.Trim() + $newline + $newline
        [string]$trgContent = $trgContent + $templateContent
    }
    else {
        Write-Information " --> NO Docker"
    }
    
    if($updateGitHubActions)
    {
        [string]$actionsTargetPath = makePath -Path $repoRoot -ChildPath ".github"
        $files = Get-ChildItem -Path $actionsTargetPath -Filter *.yml -Recurse
        if ($files) {
            Write-Information " --> Adding Github Actions"
            [string]$templateContent = githubActionsDependabotTemplate
            [string]$trgContent = $trgContent.Trim() + $newline + $newline
            [string]$trgContent = $trgContent + $templateContent
        }
        else {
            Write-Information " --> NO Github Actions"
        }
    }

    $files = Get-ChildItem -Path $repoRoot -Filter requirements.txt -Recurse
    if($files) {
        Write-Information " --> Adding Python"
        [string]$templateContent = pythonDependabotTemplate
        [string]$trgContent = $trgContent.Trim() + $newline + $newline
        [string]$trgContent = $trgContent +  $templateContent
    }
    else {
        Write-Information " --> NO Python"
    }
    
    [string]$trgContent = $trgContent.Trim() + $newline
    
    Write-Information " --> Done"
    Set-Content -Path $configFileName -Value $trgContent
}

Export-ModuleMember -Function Dependabot-BuildConfig
