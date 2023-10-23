
function Log-GetDate {

    [string]$now = Get-Date -AsUtc -Format "yyyy-MM-dd@HH:mm:ss"

    return $now
}

function Log-Common {
   param (
       [string]$now,
       [string]$message
   )

   Write-Information "$($now): $($message)"
}

function Log {
    param (
        [string]$message
    )

    [string]$now = Log-GetDate
    Log-Common -now $now -message $message
}

function Log-Batch {
    param (
        [string[]]$messages
    )

    [string]$now = Log-GetDate
    foreach($msg in $messages) {
        Log-Common -now $now -message $message
    }
}


Export-ModuleMember -Function Log
Export-ModuleMember -Function Log-Batch
