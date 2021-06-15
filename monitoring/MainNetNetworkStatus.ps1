function GetStatusName($status) {
    if($status -eq 2) {
        return "HAPPY"
    } elseif ($status -eq 1) {
        return "UNWELL"
    }
    else
    {
        return "DEAD"
    }
}

function SetLedStatus($led, $status) {
    $statusName = GetStatusName($status)
    
    Write-Output " => Setting LED ($led) to Show status '$statusName'"
    if($status -eq 2) {
        blink1-tool --id $led --green -q
    } elseif ($status -eq 1) {
        blink1-tool --id $led --rgb FF9900 --blink 5 -q
        blink1-tool --id $led --rgb FF9900 -q
    }
    else
    {
        blink1-tool --id $led --red --blink 5 -q
        blink1-tool --id $led --red -q
    }
}

$lights = '1A0011F8', '1A001BBB', '1A001C47', '1A0020E0', '1A00230B'

$uri = "https://ihrh8ibm9c.execute-api.eu-west-1.amazonaws.com/dev"

Try {
    $status = Invoke-WebRequest -Uri $uri | Select-Object -ExpandProperty Content | ConvertFrom-Json 

    $currentLight = 0

    foreach($env in $status) {
        $envName = $env[0].environment
        
        
        foreach($network in $env[0].networks) {
            $netName = $network[0].network
            foreach($tenant in $network[0].tenants) {
                $tenantName = $tenant[0].tenant

                
        
                foreach($domain in $tenant[0].domains) {
                    $domainName = $domain[0].domain
                    $status = $domain[0].status

                    $statusName = GetStatusName($status)
                    Write-Output "Casino $envName/$netName/$tenantName/$domainName : $statusName"

                    if($currentLight -lt $lights.length) {
                        $led = $lights[$currentLight]
                        
                        SetLedStatus $led $status

                        $currentLight += 1
                    }
            
                }
            }
        }
    }
    
}
Catch {
    Write-Error "$uri : Error"

    foreach ($led in $lights) {
        SetLedStatus $led 0
    }
}
