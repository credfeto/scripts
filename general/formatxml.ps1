param(
    [string] $inputFile = $(throw "Please enter an input file name"),
    [string] $outputFile = $(throw "Please supply an output file name")
)

$data = [xml](Get-Content $inputFile)

$xws = new-object System.Xml.XmlWriterSettings
$xws.Indent = $true
$xws.IndentChars = "  "
$xws.NewLineOnAttributes = $false

$data.Save([Xml.XmlWriter]::Create($outputFile, $xws))