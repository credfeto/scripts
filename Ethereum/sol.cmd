@echo off

IF "%1" == "" goto usage

SET OUTPUTFOLDER=d:\Work\SolidityCompiled

echo ************************************************************************************
echo Compiling %1.....
echo.
solc --optimize-runs 1000 -o %OUTPUTFOLDER% --overwrite --ast --bin --hashes %1  
IF ERRORLEVEL 1 GOTO :errors 

solhint %1

rem solium --file %1 

goto finish

:usage
echo %0 filename.sol

goto finish

:errors

ECHO (%ERRORLEVEL%) Errors

:finish