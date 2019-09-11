$when = Get-Date -Format "dddd MM/dd/yyyy HH:mm K"

New-SelfSignedCertificate -DnsName *.ocaltest.me -CertStoreLocation cert:\LocalMachine\My -KeyLength 2048 -HashAlgorithm sha256  -KeyFriendlyName "LocalTest.me Wild Card {$when}"

