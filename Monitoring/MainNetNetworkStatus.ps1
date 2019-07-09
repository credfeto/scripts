function CheckUrl($uri, $led) {
    Try {

        $status = Invoke-WebRequest -Uri $uri | Select-Object -ExpandProperty Content 

        $status

        if($status -eq "2") {
            blink1-tool --id $led --green
        } elseif ($status -eq "1") {
            blink1-tool --id $led --rgb FF9900 --blink 5
            blink1-tool --id $led --rgb FF9900
        }
        else
        {
            blink1-tool --id $led --red --blink 5
            blink1-tool --id $led --red
        }
    }
    Catch {
        blink1-tool --id $led --red --blink 5
        blink1-tool --id $led --red
    }
}


CheckUrl 'https://casinofair.com/api/networks/health?NetworkId=1' '1A0011F8'

CheckUrl 'https://showcase.funfair.io/api/networks/health?NetworkId=4' '1A001BBB'

CheckUrl 'https://staging.funfair.io/api/networks/health?NetworkId=1' '1A001C47'

CheckUrl 'https://dev.funfair.io/api/networks/health?NetworkId=1' '1A0020E0'

CheckUrl 'https://localhost:5001/api/networks/health?NetworkId=1984' '1A00230B'

