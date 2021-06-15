@echo off
rem clear the http cache so can see the latest set of packages
nuget locals http-cache -clear

SET SPEC=FunFair.
SET UPDATER=D:/Work/UpdatePackages/UpdatePackages/bin/Debug/netcoreapp2.1/UpdatePackages.dll

dotnet %UPDATER% -folder D:\Work -prefix %SPEC%

SET SPEC=FluentValidation
dotnet %UPDATER% -folder D:\Work -prefix %SPEC%

SET SPEC=Microsoft
dotnet %UPDATER% -folder D:\Work -prefix %SPEC%



rem call resetnugetcache.cmd
