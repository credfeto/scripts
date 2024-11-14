#! /bin/sh

sudo trust anchor --store ./certs/api.nuget.local.pem
sudo trust anchor --store ./certs/funfair.nuget.local.pem
sudo trust anchor --store ./certs/funfair-prerelease.nuget.local.pem
sudo trust anchor --store ./certs/npm.local.pem