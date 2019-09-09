function CheckUrl($uri, $led) {
    Try {

        $status = Invoke-WebRequest -Uri $uri | Select-Object -ExpandProperty Content 



        if($status -eq "2") {
    	    Write-Output "$uri : $status"
            blink1-tool --id $led --green
        } elseif ($status -eq "1") {
    	    Write-Warning "$uri : $status"
            blink1-tool --id $led --rgb FF9900 --blink 5
            blink1-tool --id $led --rgb FF9900
        }
        else
        {
    	    Write-Error "$uri : $status"
            blink1-tool --id $led --red --blink 5
            blink1-tool --id $led --red
        }
    }
    Catch {
  	Write-Error "$uri : Error"
        blink1-tool --id $led --red --blink 5
        blink1-tool --id $led --red
    }
}


CheckUrl 'https://casinofair.com/api/networks/health?NetworkId=1' '1A0011F8'

CheckUrl 'https://cryptocasino.com/api/networks/health?NetworkId=1' '1A001BBB'

CheckUrl 'https://showcase.funfair.io/api/networks/health?NetworkId=4' '1A001C47'

CheckUrl 'https://staging.casinofair.io/api/networks/health?NetworkId=1' '1A0020E0'

CheckUrl 'https://dev.funfair.io/api/networks/health?NetworkId=1' '1A00230B'

