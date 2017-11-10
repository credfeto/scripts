@echo off
IF "%WORK%" EQU "" SET WORK=%TEMP%
SET FILENAME=%WORK%\Rinkeby.log
echo %FILENAME%

REM echo.>> %FILENAME%
REM echo.>> %FILENAME%

REM echo ==================================================================================== >> %FILENAME%
REM echo %DATE% %TIME% >> %FILENAME%
REM curl http://github-faucet.kovan.network/url --data "address=https://gist.github.com/credfeto/11f8fda74bc86d5199b1bf0a5feb1384" >> %FILENAME%
REM https://plus.google.com/+MarkRidgwell/posts/L3raHeqRPKa