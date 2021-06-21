SET EXE=C:\Program Files (x86)\Red Gate\SQL Compare 14\SQLCompare.exe
SET SOURCE=D:\Work\funfair-ethereum-proxy-server\db
SET FILTER=%SOURCE%\Filter.scpf
SET SOURCE=D:\Test\Extract
SET SERVER1=localhost
SET SERVER1DB=MTRTest
SET OUTPUT=D:\DB.sql
SET REPORT=D:\DB.xml
SET LOG=D:\DB.log

REM sqlcmd -S %SERVER2% -b -e -Q "IF EXISTS(SELECT Name from sys.Databases WHERE name = '%SERVER2DB%') ALTER DATABASE %SERVER2DB% SET SINGLE_USER WITH ROLLBACK IMMEDIATE"
REM sqlcmd -S %SERVER2% -b -e -Q "IF EXISTS(SELECT Name from sys.Databases WHERE name = '%SERVER2DB%') DROP DATABASE %SERVER2DB%"
REM sqlcmd -S %SERVER2% -b -e -Q "CREATE DATABASE %SERVER2DB%"


"%EXE%" "/filter:%FILTER%" /options:ConsiderNextFilegroupInPartitionSchemes,DecryptPost2kEncryptedObjects,DoNotOutputCommentHeader,ForceColumnOrder,IgnoreCertificatesAndCryptoKeys,IgnoreDatabaseAndServerName,IgnoreUserProperties,IgnoreUsersPermissionsAndRoleMemberships,IgnoreWhiteSpace,IgnoreWithElementOrder,IncludeDependencies,NoDeploymentLogging,ThrowOnFileParseFailed,UseCompatibilityLevel /transactionIsolationLevel:SERIALIZABLE "/makescripts:%SOURCE%" /force /OutputWidth:1024 /server1:%SERVER2% /database1:%SERVER2DB% /out:"%LOG%

REM /include:staticData   == only when a source-controlled database is set as database 1
REM "/scriptFile:%OUTPUT%" 

REM sqlcmd -S %SERVER2%  -d %SERVER2DB% -i "%OUTPUT%" -b -e
