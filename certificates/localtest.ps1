$when = Get-Date -Format "dddd MM/dd/yyyy HH:mm K"

New-SelfSignedCertificate -DnsName eth-rinkeby.alchemyapi.io -CertStoreLocation cert:\LocalMachine\My -KeyLength 2048 -HashAlgorithm sha256  -KeyFriendlyName "Fake eth-rinkeby.alchemyapi.io $when"

