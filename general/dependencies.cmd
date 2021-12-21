@echo off
cls 
echo processing projects in %CD%...
REM git reset head --hard
dotnet restore
dotnet pwsh -file d:\Personal\scripts\powershell\RemoveRedundantReferences.ps1 -solutionDirectory %CD%