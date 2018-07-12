@echo off
cd /d d:\work\
call settitle.cmd

start "FunServer" cd /d d:\work\cd FunServer
start "Common" cd /d d:\work\cd Common
start "Ethereum" cd /d d:\work\cd Ethereum
start "ContentPackageManagement" cd /d d:\work\ContentPackageManagement
start "ContentPackageBuilder" cd d:\work\ContentPackageBuilder