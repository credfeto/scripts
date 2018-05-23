@echo off
SET SPEC=FunFair.
SET UPDATER=D:/Work/UpdatePackages/UpdatePackages/bin/Debug/netcoreapp2.0/UpdatePackages.dll
for /f "usebackq tokens=1,2 delims= " %%a in (`nuget.exe list %SPEC%`) do dotnet %UPDATER% %%a %%b

call resetnugetcache.cmd
