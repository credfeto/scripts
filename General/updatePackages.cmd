@echo off
SET SPEC=FunFair.
SET UPDATER=D:/Work/UpdatePackages/UpdatePackages/bin/Debug/netcoreapp2.0/UpdatePackages.dll

dotnet %UPDATER% -folder D:\Work -prefix %SPEC%

rem call resetnugetcache.cmd
