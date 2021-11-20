<#
#requires -Module Microsoft.PowerShell.GraphicalTools
#>

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
if ($isLinux) {
    $in = $(import-csv (Get-ChildItem "$root\out" -Filter "*-output.csv" | Select-Object name, fullname | Sort-Object -Property name -Descending | Out-GridView -PassThru).fullname -delimiter ',' -encoding "UTF8")
} else {
    $in = $(import-csv (Get-ChildItem "$root/out" -Filter "*-output.csv" | Select-Object name, fullname | Sort-Object -Property name -Descending | Out-ConsoleGridView).fullname -delimiter ',' -encoding "UTF8")
}
foreach ($e in $($in.election | Select-Object -unique)) {
    $r = Invoke-WebRequest -uri "$base/elections/$e/close" -WebSession $session -method POST -Body @{
        "csrfmiddlewaretoken" = $csrfRegex.matches(($r.Content -split "`n" | select-string "csrfmiddlewaretoken")[0]).captures.groups[1].value
    } -Headers @{
        "Referer" = "$base/elections/$e"
        "Origin"  = $base
    }
}


########## end election form in panel ####################

try { $credentials = import-clixml "$root\$($base -replace "https://").cred" }
catch {
    $credentials = get-credential -Message "Panel login"
    if ($Host.UI.PromptForChoice("Security", "Do you want to save credentials?", @("No", "Yes"), 0)) {
        $credentials | Export-Clixml "$root\$($base -replace "https://").cred"
    }
}

$s = Invoke-WebRequest -uri "$base" -method GET -SessionVariable "rse" @commonParams -headers @{
    "Referer" = "$base/members/sign_in"
    "Origin"  = $base
}
$s.Content -match "`n.*csrf-token""\ content=""(?'token'.*)"".*`n" | Out-Null
$authToken = $matches.token
$s = Invoke-WebRequest -uri "$base/members/sign_in" -method POST -websession $rse @commonParams -headers @{
    "Referer" = "$base/members/sign_in"
    "Origin"  = $base
} -body @{
    "utf8"               = "✓"
    "authenticity_token" = $authToken
    "member[email]"      = $credentials.UserName
    "member[password]"   = $credentials.GetNetworkCredential().Password
    "commit"             = "Zaloguj się"
}

$s.Content -match "`n.*csrf-token""\ content=""(?'token'.*)"".*`n" | Out-Null
$authToken = $matches.token

foreach ($e in $in) {

    
    $s = Invoke-WebRequest -uri "$base/elections/$($e.electionID)" -method POST -websession $rse @commonParams -headers @{
        "Referer" = "$base/elections"
        "Origin"  = $base
    } -body @{
        "utf8"                       = "✓"
        "authenticity_token"         = $authToken
        "election[active]"           = "0"
        "election[answers_editable]" = "0"
        "commit"                     = "Zapisz wybory"
    }
    $s.Content -match "`n.*csrf-token""\ content=""(?'token'.*)"".*`n" | Out-Null
    $authToken = $matches.token
}