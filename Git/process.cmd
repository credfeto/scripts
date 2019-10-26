@echo off


rem git@github.com:funfair-tech/funfair-build-check.git

SET ROOT=%CD%
echo %ROOT%

for /F %%a in (%ROOT%\repos.lst) do call :checkrepo %%a

goto :finish

:updatepackage
setlocal ENABLEDELAYEDEXPANSION
set PACKAGE=%1

ECHO * %PACKAGE%

git reset head --hard
git clean -f -x -d
git checkout master
git reset head --hard
git clean -f -x -d

%ROOT%\UpdatePackages\UpdatePackages\bin\Release\netcoreapp3.0\UpdatePackages.exe -folder "%ROOT%\%FOLDER%" -prefix "%PACKAGE%"
if exist src\*.sln cd src

dotnet build --configuration Release
IF ERRORLEVEL == 0 call :commit %PACKAGE%

endlocal
goto :EOF

:commit
echo *************************** UPDATE %1 ***************************
git add -A
git commit -m"FF-1429 Updated Code %1 analysis package to latest version"
git push
echo *************************** UPDATE %1 ***************************

goto :EOF


:checkrepo
setlocal
SET REPO=%1
echo.
echo Repo: %REPO%
SET FOLDER=
for /F "tokens=1,2,3 delims=:/" %%b in ("%1") do set FOLDER=%%d
SET FOLDER=%FOLDER:~0,-4%
echo %FOLDER%

IF NOT EXIST %ROOT%\%FOLDER%\.git\HEAD git clone %REPO%
cd /d %ROOT%
PUSHD %ROOT%\%FOLDER%
ECHO %CD%

git fetch
git rebase

call :updatepackage AsyncFixer
call :updatepackage NSubstitute.Analyzers.CSharp
call :updatepackage Microsoft.CodeAnalysis.FxCopAnalyzers
call :updatepackage SonarAnalyzer.CSharp
call :updatepackage xunit.analyzers
call :updatepackage SourceLink.Create.CommandLine

POPD

REM rd /s /q %ROOT%\%FOLDER%

endlocal
goto :EOF




:finish