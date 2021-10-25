
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
  - dependency-name: ""MaxMind.GeoIP2""
  - dependency-name: ""MaxMind.MinFraud""
  - dependency-name: ""Microsoft.ApplicationInsights.AspNetCore""
  - dependency-name: ""Microsoft.NET.Test.Sdk""
  - dependency-name: ""Microsoft.VisualStudio.Threading.Analyzers""
  - dependency-name: ""NBitcoin""
  - dependency-name: ""Newtonsoft.Json""
  - dependency-name: ""NSubstitute""
  - dependency-name: ""NSubstitute.Analyzers.CSharp""
  - dependency-name: ""Octopus.Client""
  - dependency-name: ""Portable.BouncyCastle""
  - dependency-name: ""Profanity.Detector""
  - dependency-name: ""Roslynator.Analyzers""
  - dependency-name: ""ScottPlot""
  - dependency-name: ""SonarAnalyzer.CSharp""
  - dependency-name: ""SourceLink.Create.CommandLine""
  - dependency-name: ""TeamCity.VSTest.TestAdapter""
  - dependency-name: ""ToStringWithoutOverrideAnalyzer""
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
    return "
- package-ecosystem: npm
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
    $ChildPath = convertToOsPath -path $ChildPath

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
    [string] $configFileName,
    [string] $repoRoot,
    [bool] $updateGitHubActions,
    [bool] $hasSubModules
    )

    Write-Information "Building Dependabot Config:"
    $trgContent = "version: 2
updates:
"
    
    $newline = "`r`n"

    if($hasSubModules -eq $true)
    {
        Write-Information " --> Adding Git Submodules"
        $templateContent = githubSubmodulesDependabotTemplate
        $trgContent = $trgContent.Trim() + $newline + $newline
        $trgContent = $trgContent + $templateContent
    }

    $files = Get-ChildItem -Path $trgRepo -Filter *.csproj -Recurse
    if($files -ne $null) {
        Write-Information " --> Adding .NET"
        $templateContent = dotNetDependabotTemplate
        $trgContent = $trgContent.Trim() + $newline + $newline
        $trgContent = $trgContent + $templateContent
    }
    
    $files = Get-ChildItem -Path $trgRepo -Filter 'package.json' -Recurse
    if($files -ne $null) {
        Write-Information " --> Adding Javascript"
        $templateContent = javascriptDependabotTemplate
        $trgContent = $trgContent.Trim() + $newline + $newline
        $trgContent = $trgContent + $templateContent
    }
    
    $files = Get-ChildItem -Path $trgRepo -Filter 'Dockerfile' -Recurse
    if($files -ne $null) {
        Write-Information " --> Adding Docker"
        $templateContent = dockerDependabotTemplate
        $trgContent = $trgContent.Trim() + $newline + $newline
        $trgContent = $trgContent + $templateContent
    }
    
    if($updateGitHubActions -eq $true)
    {
        $actionsTargetPath = makePath -Path $trgRepo -ChildPath ".github"
        $files = Get-ChildItem -Path $actionsTargetPath -Filter *.yml -Recurse
        if ($files -ne $null)
        {
            Write-Information " --> Adding Github Actions"
            $templateContent = githubActionsDependabotTemplate
            $trgContent = $trgContent.Trim() + $newline + $newline
            $trgContent = $trgContent + $templateContent
        }
    }

    $actionsTargetPath = makePath -Path $trgRepo -ChildPath ".github"
    $files = Get-ChildItem -Path $actionsTargetPath -Filter requirements.txt -Recurse
    if($files -ne $null) {
        Write-Information " --> Adding Python"
        $templateContent = pythonDependabotTemplate
        $trgContent = $trgContent.Trim() + $newline + $newline
        $trgContent = $trgContent +  $templateContent
    }
    
    $trgContent = $trgContent.Trim() + $newline
    
    Write-Information " --> Done"
    Set-Content -Path $configFileName -Value $trgContent

}

Export-ModuleMember -Function Dependabot-BuildConfig
