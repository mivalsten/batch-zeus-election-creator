#Import-module Microsoft.PowerShell.GraphicalTools

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
        $credentials | Export-Clixml $root/zeus.cred
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
if ($isWindows) {
    $in = $(import-csv (Get-ChildItem "$root\out" -Filter "*-output.csv" | Select-Object name, fullname | Sort-Object -Property name -Descending | Out-GridView -PassThru).fullname -delimiter ',' -encoding "UTF8")
} else {
    $in = $(import-csv (Get-ChildItem "$root/out" -Filter "*-output.csv" | Select-Object name, fullname | Sort-Object -Property name -Descending | Out-ConsoleGridView).fullname -delimiter ',' -encoding "UTF8")
}

foreach ($e in $in) {
    $r = Invoke-WebRequest -uri "$base/elections/$($e.election)/freeze" -WebSession $session -method POST -Body @{
        "csrfmiddlewaretoken" = $csrfRegex.matches(($r.Content -split "`n" | select-string "csrfmiddlewaretoken")[0]).captures.groups[1].value
    } -Headers @{
        "Referer" = "$base/elections/$($e.election)"
        "Origin"  = $base
    }
}


foreach ($e in $in) {
    $r = Invoke-WebRequest -uri "$base/elections/$($e.election)/polls/$($e.poll)/voters/email" -WebSession $session -method POST -Body @{
        "csrfmiddlewaretoken" = $csrfRegex.matches(($r.Content -split "`n" | select-string "csrfmiddlewaretoken")[0]).captures.groups[1].value
        "template"            = "vote"
        "voter_id"            = ""
        "email_subject"       = if (($in |? {$_.name -eq $e.name}).count -eq 1) {$e.name} else {"$($e.name) - $($e.pollName)"}
        "email_body"          = "W przypadku problemów z logowaniem otwórz link do głosowania w trybie incognito. W tym celu kliknij w link prawym przyciskiem myszy i wybierz `"Otwórz w trybie incognito`" lub podobnie brzmiącą opcję. W razie problemów, skontaktuj się ze swoim Zarządem Okręgu."
        "send_to"             = "all"
        "sms_body"            = ""
        "contact_method"      = "email"
        "notify_once"         = "False"
    } -Headers @{
        "Referer" = "$base/elections/$($e.election)/polls/$($e.poll)/voters/email"
        "Origin"  = $base
    }
}