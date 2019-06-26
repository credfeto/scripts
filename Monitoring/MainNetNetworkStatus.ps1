Try {

    $status = Invoke-WebRequest -Uri https://casinofair.com/api/networks/health?NetworkId=1  | Select-Object -ExpandProperty Content 

    $status


    if($status -eq "2") {
        blink1-tool --id 0 --green
    } elseif ($status -eq "1") {
        blink1-tool --id 0 --rgb FF9900 --blink 5
        blink1-tool --id 0 --rgb FF9900
    }
    else
    {
        blink1-tool --id 0 --red --blink 5
        blink1-tool --id 0 --red
    }
}
Catch {
    blink1-tool --id 0 --red --blink 5
    blink1-tool --id 0 --red
}


Try {

    $status = Invoke-WebRequest -Uri https://showcase.funfair.io/api/networks/health?NetworkId=4  | Select-Object -ExpandProperty Content 

    $status


    if($status -eq "2") {
        blink1-tool --id 1 --green
    } elseif ($status -eq "1") {
        blink1-tool --id 1 --rgb FF9900 --blink 5
        blink1-tool --id 1 --rgb FF9900
    }
    else
    {
        blink1-tool --id 1 --red --blink 5
        blink1-tool --id 1 --red
    }
}
Catch {
    blink1-tool --id 1 --red --blink 5
    blink1-tool --id 1 --red
}



Try {

    $status = Invoke-WebRequest -Uri https://staging.funfair.io/api/networks/health?NetworkId=1  | Select-Object -ExpandProperty Content 

    $status


    if($status -eq "2") {
        blink1-tool --id 2  --green
    } elseif ($status -eq "1") {
        blink1-tool --id 2 --rgb FF9900 --blink 5
        blink1-tool --id 2 --rgb FF9900
    }
    else
    {
        blink1-tool --id 2 --red --blink 5
        blink1-tool --id 2 --red
    }
}
Catch {
    blink1-tool --id 2 --red --blink 5
    blink1-tool --id 2 --red
}

Try {

    $status = Invoke-WebRequest -Uri https://dev.funfair.io/api/networks/health?NetworkId=1  | Select-Object -ExpandProperty Content 

    $status


    if($status -eq "2") {
        blink1-tool --id 3  --green
    } elseif ($status -eq "1") {
        blink1-tool --id 3 --rgb FF9900 --blink 5
        blink1-tool --id 3 --rgb FF9900
    }
    else
    {
        blink1-tool --id 3 --red --blink 5
        blink1-tool --id 3 --red
    }
}
Catch {
    blink1-tool --id 3 --red --blink 5
    blink1-tool --id 3 --red
}



Try {

    $status = Invoke-WebRequest -Uri https://localhost:5001/api/networks/health?NetworkId=1984  | Select-Object -ExpandProperty Content 

    $status


    if($status -eq "2") {
        blink1-tool --id 4  --green
    } elseif ($status -eq "1") {
        blink1-tool --id 4 --rgb FF9900 --blink 5
        blink1-tool --id 4 --rgb FF9900
    }
    else
    {
        blink1-tool --id 4 --red --blink 5
        blink1-tool --id 4 --red
    }
}
Catch {
    blink1-tool --id 4 --red --blink 5
    blink1-tool --id 4 --red
}

