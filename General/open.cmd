@echo off
cd /d d:\work\
call settitle.cmd

start "FunServer" cd /d d:\work\FunServer
start "FunWallet-Server" cd /d d:\work\FunWallet-Server
start "Common" cd /d d:\work\Common
start "Ethereum" cd /d d:\work\Ethereum
start "ContentPackageManagement" cd /d d:\work\ContentPackageManagement
start "ContentPackageBuilder" cd d:\work\ContentPackageBuilder
start "Scripts" cd /d d:\work\Scripts