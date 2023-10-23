
function Log {
    param (
        [Parameter(Mandatory=$true)]
        [string]$message
    )

    [string]$now = Get-Date -AsUtc -Format "yyyy-mm-dd@HH-mm:ss"
    Write-Information "$now - $message"
}

function Log-Batch {
    param (
        [Parameter(Mandatory=$true)]
        [string[]]$messages
    )

    [string]$now = Get-Date -AsUtc -Format "yyyy-mm-dd@HH-mm:ss"
    foreach($msg in $messages) {
        Write-Information "$now - $msg"
    }
}


Export-ModuleMember -Function Log
Export-ModuleMember -Function Log-Batch
