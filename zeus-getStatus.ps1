$commonParams = @{
    #"Proxy" = ""
    #"ProxyUseDefaultCredential" = $true
}

$base = "https://zeus.partiarazem.pl"
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
if ($isLinux) {
    $in = $(import-csv (Get-ChildItem "$root\out" -Filter "*-output.csv" | Select-Object name, fullname | Sort-Object -Property name -Descending | Out-GridView -PassThru).fullname -delimiter ',' -encoding "UTF8")
} else {
    $in = $(import-csv (Get-ChildItem "$root/out" -Filter "*-output.csv" | Select-Object name, fullname | Sort-Object -Property name -Descending | Out-ConsoleGridView).fullname -delimiter ',' -encoding "UTF8")
}
foreach ($e in $in) {
    $r = Invoke-WebRequest -uri "$base/elections/$($e.election)/polls/" -WebSession $session -method GET -Headers @{
        "Referer" = "$base/elections/$($e.election)"
        "Origin"  = $base
    }
    $r.content -match "(?ms)<tr data-uuid=`"$($e.poll).*?</tr>" | Out-Null
    $t = $matches[0]
    $t = $t -replace "`r" -replace "`n" -replace " " -replace "</td><td>", ";" -replace "<div.*?div>" -replace "<td>", "#!#!" -replace "<.*?>" -split "#!#!"
    $t | ForEach-Object {
        if ($_ -ne "") {
            $a = $_ -split ';'
            write-output "$(if (($in |? {$_.name -eq $e.name}).count -eq 1) {$e.name} else {"$($e.name): $($e.pollName)"}) - uprawnione $($a[3]), powiadomione $($a[4]), zagłosowało $($a[5]), frekwencja $([math]::Round($($a[5])/$($a[3])*100,1))%"
        }
    }
}