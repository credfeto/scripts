@echo off

for /f usebackq %%a in (`git tag`) do call DeleteTagLocallyAndRemote %%a