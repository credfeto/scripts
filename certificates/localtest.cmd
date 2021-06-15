@echo off
SETLOCAL

@echo Generating Root CA
makecert -a sha256 -n "CN=localtest.me" -r -ss root -sr localMachine

@echo Generating Wildcard cert
makecert -a sha256 -pe -is root -ir localMachine -in localtest.me -n "CN=*.localtest.me" -eku 1.3.6.1.5.5.7.3.1 -ss my -sr localmachine -sky exchange

ENDLOCAL