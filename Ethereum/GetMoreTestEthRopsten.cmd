@echo off
IF "%WORK%" EQU "" SET WORK=%TEMP%
SET FILENAME=%WORK%\Ropsten.log
echo %FILENAME%

echo.>> %FILENAME%
echo.>> %FILENAME%

echo ==================================================================================== >> %FILENAME%
echo %DATE% %TIME% >> %FILENAME%
curl "https://faucet.ropsten.be/donate/0xed05D0734a600f265Bc7959999794306e27527Ea" -H "Pragma: no-cache" -H "DNT: 1" -H "Accept-Language: en-GB,en-US;q=0.8,en;q=0.6" -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/61.0.3163.100 Safari/537.36" -H "accept: application/json" -H "Referer: https://faucet.ropsten.be/donate/" -H "Connection: keep-alive" -H "Cache-Control: no-cache">> %FILENAME%