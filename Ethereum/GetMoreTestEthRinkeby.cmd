@echo off
IF "%WORK%" EQU "" SET WORK=%TEMP%
SET FILENAME=%WORK%\Rinkeby.log
echo %FILENAME%

REM echo.>> %FILENAME%
REM echo.>> %FILENAME%


REM ME
curl http://rinkeby-faucet.com/send?address=0xed05d0734a600f265bc7959999794306e27527ea -H "Connection: keep-alive" -H "Pragma: no-cache" -H "Cache-Control: no-cache" -H "Upgrade-Insecure-Requests: 1" -H "DNT: 1" -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/69.0.3497.100 Safari/537.36" -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8" -H "Referer: http://rinkeby-faucet.com/" -H "Accept-Language: en-GB,en;q=0.9,en-US;q=0.8"  >> %FILENAME%

rem DEV.FUNFAIR.IO
curl http://rinkeby-faucet.com/send?address=0x735c8A095933672A8Cc405843eaf333Ab2E6eAfC   -H "Connection: keep-alive" -H "Pragma: no-cache" -H "Cache-Control: no-cache" -H "Upgrade-Insecure-Requests: 1" -H "DNT: 1" -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/69.0.3497.100 Safari/537.36" -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8" -H "Referer: http://rinkeby-faucet.com/" -H "Accept-Language: en-GB,en;q=0.9,en-US;q=0.8"  >> %FILENAME%

REM STAGING.FUNFAIR.IO
curl http://rinkeby-faucet.com/send?address=0x11cEc7c5Adb845402C405Fd4dfEA6c869cd9c34a -H "Connection: keep-alive" -H "Pragma: no-cache" -H "Cache-Control: no-cache" -H "Upgrade-Insecure-Requests: 1" -H "DNT: 1" -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/69.0.3497.100 Safari/537.36" -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8" -H "Referer: http://rinkeby-faucet.com/" -H "Accept-Language: en-GB,en;q=0.9,en-US;q=0.8"  >> %FILENAME%

REM SHOWCASE.FUNFAIR.IO
curl http://rinkeby-faucet.com/send?address=0x22FbAC74f447717234DF4C3B5b28e25Cec0fd12f -H "Connection: keep-alive" -H "Pragma: no-cache" -H "Cache-Control: no-cache" -H "Upgrade-Insecure-Requests: 1" -H "DNT: 1" -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/69.0.3497.100 Safari/537.36" -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8" -H "Referer: http://rinkeby-faucet.com/" -H "Accept-Language: en-GB,en;q=0.9,en-US;q=0.8"  >> %FILENAME%

REM: ME
REM https://twitter.com/mtrphotos/status/1133772485202194432