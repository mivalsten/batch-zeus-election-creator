$commonParams = @{
    #"Proxy" = ""
    #"ProxyUseDefaultCredential" = $true
}

$base = "https://zeus.int.partiarazem.pl"
$root = $PSScriptRoot
$csrfRegex = [regex]::New(".*value=`"(.*)`"")

try { $credentials = import-clixml "$root\$($base -replace "https://").cred" }
catch {
    $credentials = get-credential -Message "Zeus login"
    if ($Host.UI.PromptForChoice("Security", "Do you want to save credentials?", @("No", "Yes"), 0)) {
        $credentials | Export-Clixml "$root\$($base -replace "https://").cred"
    }
}

#extract CSRF token
$r = Invoke-WebRequest -uri "$base/auth/auth/login" -SessionVariable "session" @commonParams

#login
$r = Invoke-WebRequest -uri "$base/auth/auth/login" -WebSession $session -method POST -Body @{
    "username"            = $credentials.UserName
    "password"            = $credentials.GetNetworkCredential().password
    "csrfmiddlewaretoken" = $csrfRegex.matches(($r.Content -split "`n" | select-string "csrfmiddlewaretoken")[0]).captures.groups[1].value
} -Headers @{
    "Referer" = "$base/auth/auth/login"
    "Origin"  = $base
}
$in = $(import-csv (Get-ChildItem "$root\out" -Filter "*-output.csv" | Select-Object name, fullname | Sort-Object -Property name -Descending | Out-GridView -PassThru).fullname -delimiter ',' -encoding "UTF8")
$i = 1
foreach ($e in $in) {

    Write-Output "**$(get-date -Format "U-\K\KW-yyyy-MM-dd")-$i**"
    Write-Output "$($e.name) - $($e.pollName) zostały zakończone. Wybrano następujące osoby:"
    $r = Invoke-WebRequest -uri "$base/elections/$($e.election)/polls/$($e.poll)/results-pl.pdf" -WebSession $session -method GET -Headers @{
        "Referer" = "$base/elections/$($e.election)"
        "Origin"  = $base
    } -OutFile "$root\out\$($e.name -replace ' ', '-')-$($e.pollName -replace ' ', '-')-wynik.pdf"
    $r = Invoke-WebRequest -uri "$base/elections/$($e.election)/polls/$($e.poll)/results-pl.csv" -WebSession $session -method GET -Headers @{
        "Referer" = "$base/elections/$($e.election)"
        "Origin"  = $base
    } -OutFile "$root\out\$($e.name -replace ' ', '-')-$($e.pollName -replace ' ', '-')-wynik.csv"
    $start = $false
    $end = $false
    $karty = $false
    $glos = 0
    get-content "$root\out\$($e.name -replace ' ', '-')-$($e.pollName -replace ' ', '-')-wynik.csv" | ForEach-Object {
        if ($_ -eq "Runda 1") {$end = $true}
        if ($start -and -not $end -and $_ -ne "") {write-output "- $_"}
        if ($_ -eq "Wybrano,Grupy") {$start = $true}
        if ($_ -match "Głosujący,(\d{1,})") {$upr = $matches[1]}
        if ($karty) {$glos++}
        if ($_ -eq "Karty do głosowania") {$karty = $true}
    }
    Write-Output "`nOdwołania można składać do $($(get-date).AddDays(7).ToShortDateString()).`n`nFrekwencja $glos / $upr, ~$([math]::Round(($glos/$upr)*100,1))%`n`n---`n"
    $i++
}