@echo off
IF "%WORK%" EQU "" SET WORK=%TEMP%
SET FILENAME=%WORK%\Kovan.log
echo %FILENAME%

echo.>> %FILENAME%
echo.>> %FILENAME%

echo ==================================================================================== >> %FILENAME%
echo %DATE% %TIME% >> %FILENAME%
curl http://github-faucet.kovan.network/url --data "address=https://gist.github.com/credfeto/11f8fda74bc86d5199b1bf0a5feb1384" >> %FILENAME%