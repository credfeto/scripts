@echo off
cls 
echo Echo processing projects in %CD%...
git reset head --hard
dotnet restore
powershell -file d:\Work\Personal\scripts\powershell\RemoveRedundantReferences.ps1 -solutionDirectory %CD%