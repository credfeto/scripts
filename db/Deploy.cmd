SET EXE=C:\Program Files (x86)\Red Gate\SQL Compare 14\SQLCompare.exe
SET SOURCE=D:\Work\funfair-ethereum-proxy-server\db
SET FILTER=%SOURCE%\Filter.scpf
SET SERVER2=localhost
SET SERVER2DB=MTRTest
SET OUTPUT=D:\DB.sql
SET REPORT=D:\DB.xml
SET LOG=D:\DB.log

sqlcmd -S %SERVER2% -b -e -Q "IF EXISTS(SELECT Name from sys.Databases WHERE name = '%SERVER2DB%') ALTER DATABASE %SERVER2DB% SET SINGLE_USER WITH ROLLBACK IMMEDIATE"
sqlcmd -S %SERVER2% -b -e -Q "IF EXISTS(SELECT Name from sys.Databases WHERE name = '%SERVER2DB%') DROP DATABASE %SERVER2DB%"
sqlcmd -S %SERVER2% -b -e -Q "CREATE DATABASE %SERVER2DB%"


REM Assert Idenitcal
REM "%EXE%" "/filter:%FILTER%" /options:ConsiderNextFilegroupInPartitionSchemes,DecryptPost2kEncryptedObjects,DoNotOutputCommentHeader,ForceColumnOrder,IgnoreCertificatesAndCryptoKeys,IgnoreDatabaseAndServerName,IgnoreUserProperties,IgnoreUsersPermissionsAndRoleMemberships,IgnoreWhiteSpace,IgnoreWithElementOrder,IncludeDependencies,NoDeploymentLogging,ThrowOnFileParseFailed,UseCompatibilityLevel /transactionIsolationLevel:SERIALIZABLE /include:staticData "/scriptFile:%OUTPUT%" /showWarnings /include:Identical "/report:%REPORT%" /reportType:Xml /assertidentical /force /OutputWidth:1024 "/scripts1:%SOURCE%" /server2:%SERVER2% /database2:%SERVER2DB% /out:"%LOG%" /Synchronise"

REM Synchronise
"%EXE%" "/filter:%FILTER%" /options:ConsiderNextFilegroupInPartitionSchemes,DecryptPost2kEncryptedObjects,DoNotOutputCommentHeader,ForceColumnOrder,IgnoreCertificatesAndCryptoKeys,IgnoreDatabaseAndServerName,IgnoreUserProperties,IgnoreUsersPermissionsAndRoleMemberships,IgnoreWhiteSpace,IgnoreWithElementOrder,IncludeDependencies,NoDeploymentLogging,ThrowOnFileParseFailed,UseCompatibilityLevel /transactionIsolationLevel:SERIALIZABLE /include:staticData "/scriptFile:%OUTPUT%" /showWarnings /include:Identical "/report:%REPORT%" /reportType:Xml /synchronise /force /OutputWidth:1024 "/scripts1:%SOURCE%" /server2:%SERVER2% /database2:%SERVER2DB% /out:"%LOG%""

REM sqlcmd -S %SERVER2%  -d %SERVER2DB% -i "%OUTPUT%" -b -e
