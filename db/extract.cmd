SET EXE=C:\Program Files (x86)\Red Gate\SQL Compare 14\SQLCompare.exe
SET SOURCE=D:\Work\funfair-ethereum-proxy-server\db
SET FILTER=%SOURCE%\Filter.scpf
SET HOOKSXML=%TEMP%\Hooks.xml
SET DBXML=%TEMP%\dbxml.xml
REM SET SOURCE=D:\Test\Extract
SET SERVER1=localhost
SET SERVER1DB=EthereumClientProxy
SET OUTPUT=D:\DB.sql
SET REPORT=D:\DB.xml
SET LOG=D:\DB.log

REM sqlcmd -S %SERVER2% -b -e -Q "IF EXISTS(SELECT Name from sys.Databases WHERE name = '%SERVER2DB%') ALTER DATABASE %SERVER2DB% SET SINGLE_USER WITH ROLLBACK IMMEDIATE"
REM sqlcmd -S %SERVER2% -b -e -Q "IF EXISTS(SELECT Name from sys.Databases WHERE name = '%SERVER2DB%') DROP DATABASE %SERVER2DB%"
REM sqlcmd -S %SERVER2% -b -e -Q "CREATE DATABASE %SERVER2DB%"


echo ^<?xml version="1.0" encoding="utf-16" standalone="yes"?^> > %HOOKSXML%
echo ^<HooksConfig version="1" type="HooksConfig"^> >> %HOOKSXML%
echo  ^<Name^>Working Folder<^/Name^> >> %HOOKSXML%
echo  ^<Commands type="Commands" version="2"^> >> %HOOKSXML%
echo    ^<element^> >> %HOOKSXML%
echo      ^<key type="string"^>GetLatest^</key^> >> %HOOKSXML%
echo      ^<value version="1" type="GenericHookCommand"^> >> %HOOKSXML%
echo        ^<CommandLine^>^</CommandLine^> >> %HOOKSXML%
echo        ^<Verify^>exitCode == 0^</Verify^> >> %HOOKSXML%
echo      ^</value^> >> %HOOKSXML%
echo    ^</element^> >> %HOOKSXML%
echo    ^<element^> >> %HOOKSXML%
echo      ^<key type="string"^>Add^</key^> >> %HOOKSXML%
echo      ^<value version="1" type="GenericHookCommand"^> >> %HOOKSXML%
echo        ^<CommandLine^>^</CommandLine^> >> %HOOKSXML%
echo        ^<Verify^>exitCode == 0^</Verify^> >> %HOOKSXML%
echo      ^</value^> >> %HOOKSXML%
echo    ^</element^> >> %HOOKSXML%
echo    ^<element^> >> %HOOKSXML%
echo      <^key type="string"^>Edit<^/key^> >> %HOOKSXML%
echo      <^value version="1" type="GenericHookCommand"^> >> %HOOKSXML%
echo        ^<CommandLine^>^</CommandLine^> >> %HOOKSXML%
echo        ^<Verify^>exitCode == 0^</Verify^> >> %HOOKSXML%
echo      ^</value^> >> %HOOKSXML%
echo    ^</element^> >> %HOOKSXML%
echo    ^<element^> >> %HOOKSXML%
echo      ^<key type="string"^>Delete^</key^> >> %HOOKSXML%
echo      ^<value version="1" type="GenericHookCommand"^> >> %HOOKSXML%
echo        ^<CommandLine^>^</CommandLine^> >> %HOOKSXML%
echo        ^<Verify^>exitCode == 0^</Verify^> >> %HOOKSXML%
echo      ^</value^> >> %HOOKSXML%
echo    ^</element^> >> %HOOKSXML%
echo    ^<element^> >> %HOOKSXML%
echo      ^<key type="string"^>Commit^</key^> >> %HOOKSXML%
echo      ^<value version="1" type="GenericHookCommand"^> >> %HOOKSXML%
echo        ^<CommandLine^>^</CommandLine^> >> %HOOKSXML%
echo        ^<Verify^>exitCode == 0^</Verify^> >> %HOOKSXML%
echo      ^</value^> >> %HOOKSXML%
echo    ^</element^> >> %HOOKSXML%
echo    ^<element^> >> %HOOKSXML%
echo      ^<key type="string"^>Revert^</key^> >> %HOOKSXML%
echo      ^<value version="1" type="GenericHookCommand"^> >> %HOOKSXML%
echo        ^<CommandLine^>^</CommandLine^> >> %HOOKSXML%
echo        ^<Verify^>exitCode == 0^</Verify^> >> %HOOKSXML%
echo      ^</value^> >> %HOOKSXML%
echo    ^</element^> >> %HOOKSXML%
echo  ^</Commands^> >> %HOOKSXML%
echo ^</HooksConfig^> >> %HOOKSXML%


echo ^<?xml version="1.0" encoding="utf-16" standalone="yes"?^> > %DBXML%
echo ^<!-- --^> >> %DBXML%
echo ^<ISOCCompareLocation version="2" type="WorkingFolderGenericLocation" ^> >> %DBXML%
echo   ^<LocalRepositoryFolder^>%SOURCE%^</LocalRepositoryFolder^> >> %DBXML%
echo   ^<HooksConfigFile^>%HOOKSXML%^</HooksConfigFile^> >> %DBXML%
echo   ^<HooksFileInRepositoryFolder^>False^</HooksFileInRepositoryFolder^> >> %DBXML%
echo ^</ISOCCompareLocation^> >> %DBXML%

type "%DBXML%"

"%EXE%" "/filter:%FILTER%" /options:ConsiderNextFilegroupInPartitionSchemes,DecryptPost2kEncryptedObjects,DoNotOutputCommentHeader,ForceColumnOrder,IgnoreCertificatesAndCryptoKeys,IgnoreDatabaseAndServerName,IgnoreUserProperties,IgnoreUsersPermissionsAndRoleMemberships,IgnoreWhiteSpace,IgnoreWithElementOrder,IncludeDependencies,NoDeploymentLogging,ThrowOnFileParseFailed,UseCompatibilityLevel /transactionIsolationLevel:SERIALIZABLE "/makescripts:%SOURCE%" /force /OutputWidth:1024 /server1:%SERVER1% /database1:%SERVER1DB% /out:"%LOG%" /sourcecontrol2 /revision2:latest "/sfx:%DBXML%" 


REM: TODO - work out:
REM /sourcecontrol2 /revision2:latest "/scriptsfolderxml:%DBXML%" 
REM /include:staticData   == only when a source-controlled database is set as database 1
REM "/scriptFile:%OUTPUT%" 

REM sqlcmd -S %SERVER2%  -d %SERVER2DB% -i "%OUTPUT%" -b -e
