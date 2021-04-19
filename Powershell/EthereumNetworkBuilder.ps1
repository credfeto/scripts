
$srcDataPath = "C:\work\ThirdParty\chains\_data\chains"
$files = Get-ChildItem -Path $srcDataPath -Filter "*.json"

cls

$config = @(
        [pscustomobject]@{
            NetworkId = 1
            ChainId = 1
            Alias = "PublicEthereumNetworks.MAINNET"
        },
        [pscustomobject]@{
            NetworkId = 2
            ChainId = 2
            Alias = "PublicEthereumNetworks.MORDEN"
        },
        [pscustomobject]@{
            NetworkId = 3
            ChainId = 3
            Alias = "PublicEthereumNetworks.ROPSTEN"
        },
        [pscustomobject]@{
            NetworkId = 4
            ChainId = 4
            Alias = "PublicEthereumNetworks.RINKEBY"
        },
        [pscustomobject]@{
            NetworkId = 5
            ChainId = 5
            Alias = "PublicEthereumNetworks.GOERLI"
        },
        [pscustomobject]@{
            NetworkId = 42
            ChainId = 42
            Alias = "PublicEthereumNetworks.KOVAN"
        },
        [pscustomobject]@{
            NetworkId = 10
            ChainId = 10
            Alias = "Layer2EthereumNetworks.OptimismMainNet"
        },
        [pscustomobject]@{
            NetworkId = 56
            ChainId = 56
            Alias = "Layer2EthereumNetworks.BinanceSmartChain"
        },
        [pscustomobject]@{
            NetworkId = 69
            ChainId = 69
            Alias = "Layer2EthereumNetworks.OptimismKovan"
        },
        [pscustomobject]@{
            NetworkId = 100
            ChainId = 100
            Alias = "Layer2EthereumNetworks.xDai"
        },
        [pscustomobject]@{
            NetworkId = 137
            ChainId = 137
            Alias = "Layer2EthereumNetworks.Matic"
        },
        [pscustomobject]@{
            NetworkId = 420
            ChainId = 420
            Alias = "Layer2EthereumNetworks.OptimismGoerli"
        },
        [pscustomobject]@{
            NetworkId = 1287
            ChainId = 1287
            Alias = "Layer2EthereumNetworks.PolkadotMoonBeam"
        },
        [pscustomobject]@{
            NetworkId = 1
            ChainId = 43114
            Alias = "Layer2EthereumNetworks.AvalancheMainNet"
        }
        )

$list = New-Object Collections.Generic.List[String]


$list.Add("using System.Diagnostics.CodeAnalysis;")
$list.Add("using FunFair.Ethereum.DataTypes;")
$list.Add("using FunFair.Ethereum.Standard;")
$list.Add("")
$list.Add("namespace FunFair.Ethereum.Proxy.Server.Configuration.Networks")
$list.Add("{")
$list.Add("    /// <summary>")
$list.Add("    ///     Ethereum networks")
$list.Add("    /// </summary>")
$list.Add("    [SuppressMessage(category: ""ReSharper"", checkId: ""UnusedType.Global"", Justification = ""Code generated"")]")
$list.Add("    public static class EthereumNetworks")
$list.Add("    {")

$TextInfo = (Get-Culture).TextInfo

$first = $true
foreach($file in $files) {
    $fileName = $file.FullName

    Write-Host "****************************************************************************"
    Write-Host $fileName

    $network = Get-Content -Raw $fileName | ConvertFrom-JSON

    Write-Host "Name:    " $network.name
    Write-Host "Network: " $network.networkId
    Write-Host "ChainId: " $network.chainId
    Write-Host "Name:    " $network.chain $network.network
    Write-Host "Symbol:  " $network.nativeCurrency.symbol
    Write-Host "Decimals:" $network.nativeCurrency.decimals
    Write-Host "Sym Name:" $network.nativeCurrency.name

    $rpcs = $network.rpc
    if( $rpcs ) {
        foreach($endPoint in $rpcs) {
            if($endPoint.Contains('${') -eq $false) {
                Write-Host "* $endpoint"
            }
        }
    }

    $varName = $TextInfo.ToTitleCase($network.name).Replace(" ", "").Replace("-", "").Replace(".", "_")
    if([char]::IsDigit($varName[0])) {
        $varName = "X" + $varName
    }
#
#    $netName = $network.chain.ToUpperInvariant().Replace(" ", "_")
#    if($network.chain -eq "ETH") {
#        if($network.name.StartsWith("Optimistic") -eq $false) {
#            $varName = $network.network.ToUpperInvariant()
#            $netName = $network.network.ToUpperInvariant()            
#        }
#        else {
#            $varName = $network.name.Replace(" ", "")
#            $netName = $network.name.Replace(" ", "_").ToUpperInvariant()
#        }
#    }
#    elseif($network.network -ne "mainnet") {
#        $netName = $network.chain.ToUpperInvariant().Replace(" ", "_") + "_" + $network.network.ToUpperInvariant().Replace(" ", "_")
#    }

    $netName = $network.name.Replace(" ", "_").ToUpperInvariant()

    $description = $network.name
    $production = "false"
    if($network.network -eq "mainnet") {
        $production = "true"
    }

    

    $networkId = $network.networkId
    $chainId = $network.chainId
    $nativeCurrency = $network.nativeCurrency.symbol

    if($network.networkId -eq "3125659152") {
        # Pirl
        continue
    }

    if($network.networkId -eq "0") {
        # The Freight Trust Network 
        continue
    }

    if($first) {
       $first = $false
    }
    else {
        $list.Add("");
    }
    $list.Add("        /// <summary>")
    $list.Add("        ///     The $description network.")
    $list.Add("        /// </summary>")

    if( $rpcs ) {
        foreach($endPoint in $rpcs) {
            if($endPoint.Contains('${') -eq $false) {
                $list.Add("        [RpcEndPoint(""$endpoint"")]");
            }
        }
    }


    $list.Add("        [SuppressMessage(category: ""ReSharper"", checkId: ""InconsistentNaming"", Justification = ""Code generated"")]")
    $list.Add("        [SuppressMessage(category: ""ReSharper"", checkId: ""UnusedMember.Global"", Justification = ""Code generated"")]")
        
    $found = $false
    foreach($entry in $config) {
        if($entry.NetworkId -eq $networkId -and $entry.ChainId -eq $chainId) {
            $alias = $entry.Alias
            $list.Add("        public static EthereumNetwork $varName { get; } = $alias;")
            $found = $true
            break
        }
    }

    if($found -eq $false) {
        $list.Add("        public static EthereumNetwork $varName { get; } = new(")
        $list.Add("                        networkId: $networkId,")
        $list.Add("                        chainId: $chainId,")
        $list.Add("                        name: @""$netName"",")
        $list.Add("                        nativeCurrency: @""$nativeCurrency"",")
        $list.Add("                        isProduction: $production,")
        $list.Add("                        isStandalone: false,")
        $list.Add("                        isPublic: true,")
        $list.Add("                        blockExplorer: null")
        $list.Add("                        );")
    }
}

$list.Add("    }");
$list.Add("}");

Set-Content -Path C:\work\FunFair\funfair-ethereum-proxy-server\src\FunFair.Ethereum.Proxy.Server\Configuration\Networks\EthereumNetworks.cs -Value $list