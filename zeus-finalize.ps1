#requires -Module Microsoft.PowerShell.GraphicalTools

$commonParams = @{
    #"Proxy" = ""
    #"ProxyUseDefaultCredential" = $true
}

$base = "https://zeus.int.partiarazem.pl"
$root = $PSScriptRoot

try { $credentials = import-clixml $root/zeus.cred }
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
    "csrfmiddlewaretoken" = ($r.InputFields | Where-Object name -eq csrfmiddlewaretoken)[0].value
} -Headers @{
    "Referer" = "$base/auth/auth/login"
    "Origin"  = $base
}
$in = $(import-csv (Get-ChildItem "$root\out" -Filter "*-output.csv" | Select-Object name, fullname | Sort-Object -Property name -Descending | Out-GridView -PassThru).fullname -delimiter ',' -encoding "UTF8")
foreach ($e in $in) {
    $r = Invoke-WebRequest -uri "$base/elections/$($e.election)/freeze" -WebSession $session -method POST -Body @{
        "csrfmiddlewaretoken" = ($r.InputFields | Where-Object name -eq csrfmiddlewaretoken)[0].value
    } -Headers @{
        "Referer" = "$base/elections/$($e.election)"
        "Origin"  = $base
    }
}

foreach ($e in $input) {
    $r = Invoke-WebRequest -uri "$base/elections/$($e.election)/email-voters" -WebSession $session -method POST -Body @{
        "csrfmiddlewaretoken" = ($r.InputFields | Where-Object name -eq csrfmiddlewaretoken)[0].value
        "template"            = "vote"
        "voter_id"            = ""
        "email_subject"       = $e.name
        "email_body"          = ""  
        "send_to"             = "all"
        "sms_body"            = ""
        "contact_method"      = "email"
        "notify_once"         = "False"
    } -Headers @{
        "Referer" = "$base/elections/$($e.election)/email-voters"
        "Origin"  = $base
    }
}