Try {

    $status = Invoke-WebRequest -Uri https://showcase.funfair.io/api/networks/health?NetworkId=1  | Select-Object -ExpandProperty Content 
    #$status = Invoke-WebRequest -Uri https://staging.funfair.io/api/networks/health?NetworkId=1  | Select-Object -ExpandProperty Content 
    #$status = Invoke-WebRequest -Uri http://localhost:5000/api/networks/health?NetworkId=42  | Select-Object -ExpandProperty Content 

    $status


    if($status -eq "2") {
        blink1-tool  --green
    } elseif ($status -eq "1") {
        blink1-tool --rgb FF9900 --blink 5
        blink1-tool --rgb FF9900
    }
    else
    {
        blink1-tool --red --blink 5
        blink1-tool --red
    }
}
Catch {
    blink1-tool --red --blink 5
    blink1-tool --red
}