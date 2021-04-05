
$srcDataPath = "C:\work\ThirdParty\chains\_data\chains"
$files = Get-ChildItem -Path $srcDataPath -Filter "*.json"

cls

$list = New-Object Collections.Generic.List[String]


$list.Add("using System.Diagnostics.CodeAnalysis;")
$list.Add("using FunFair.Ethereum.DataTypes;")
$list.Add("using FunFair.Ethereum.DataTypes.Primitives;")
$list.Add("")
$list.Add("namespace FunFair.Ethereum.Proxy.Server.Configuration.Networks")
$list.Add("{")
$list.Add("    /// <summary>")
$list.Add("    ///     Ethereum networks")
$list.Add("    /// </summary>")
$list.Add("    public static class EthereumNetworks")
$list.Add("    {")

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

    $rpcs = $network.rpc
    if( $rpcs ) {
        foreach($endPoint in $rpcs) {
            if($endPoint.Contains('${') -eq $false) {
                Write-Host "* $endpoint"
            }
        }
    }

    $varName = $network.name.Replace(" ", "")
    $netName = $network.chain.ToUpperInvariant().Replace(" ", "_")
    if($network.chain -eq "ETH") {
        if($network.name.StartsWith("Optimistic") -eq $false) {
            $varName = $network.network.ToUpperInvariant()
            $netName = $network.network.ToUpperInvariant()            
        }
        else {
            $varName = $network.name.Replace(" ", "")
            $netName = $network.name.Replace(" ", "_").ToUpperInvariant()
        }
    }
    elseif($network.network -ne "mainnet") {
        $netName = $network.chain.ToUpperInvariant().Replace(" ", "_") + "_" + $network.network.ToUpperInvariant().Replace(" ", "_")
    }

    $description = $network.name
    $production = "false"
    if($network.network -eq "mainnet") {
        $production = "true"
    }

    $networkId = $network.networkId
    $chainId = $network.chainId


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
    $list.Add("        public static EthereumNetwork $varName { get; } = new(")
    $list.Add("                        id: $networkId,")
    $list.Add("                        chainId: $chainId,")
    $list.Add("                        name: @""$netName"",")
    $list.Add("                        isProduction: $production,")
    $list.Add("                        isStandalone: false,")
    $list.Add("                        isPublic: true);")
}

$list.Add("    }");
$list.Add("}");

Set-Content -Path C:\work\networks.cs -Value $list