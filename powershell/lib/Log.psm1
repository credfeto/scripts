
function Log-GetDate {

    [string]$now = Get-Date -AsUtc -Format "yyyy-MM-dd@HH:mm:ss"

    return $now
}

function Log-Common {
   param (
       [string]$now,
       $message
   )

   Write-Information "$($now): $($message)"
}

function ErrorLog-Common {
   param (
       [string]$now,
       $message
   )

   Write-Error "$($now): $($message)"
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
        $messages
    )

    [string]$now = Log-GetDate
    foreach($msg in $messages) {
        Log-Common -now $now -message $msg
    }
}

function ErrorLog {
    param (
        [string]$message
    )

    [string]$now = Log-GetDate
    ErrorLog-Common -now $now -message $message
}

function ErrorLog-Batch {
    param (
        $messages
    )

    [string]$now = Log-GetDate
    foreach($msg in $messages) {
        ErrorLog-Common -now $now -message $msg
    }
}


Export-ModuleMember -Function Log
Export-ModuleMember -Function Log-Batch
Export-ModuleMember -Function ErrorLog
Export-ModuleMember -Function ErrorLog-Batch
