$root = $PSScriptRoot

$base = "https://panel.partiarazem.pl"

$commonParams = @{
    #"Proxy" = ""
    #"ProxyUseDefaultCredential" = $true
}

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

$elections = Import-Csv -path $root\panel-elections.csv -Delimiter "," -Encoding utf8NoBOM

foreach ($el in $($elections.name | Select-Object -Unique)) {
    $e = ($elections | Where-Object {$_.name -eq $el}) | Select-Object -First 1
    $body = [ordered]@{
        "utf8"                                             = "✓"
        "authenticity_token"                               = $authToken
        "election[title]"                                  = $e.name
        "election[voting_start]"                           = $e.start
        "election[voting_end]"                             = $e.end
        "election[region_id]"                              = $e.regionID
        "election[province_id]"                            = $e.provinceID
        "election[instructions]"                           = ""
        "election[warning]"                                = "Zgłoszenia kandydatur są przyjmowane do $($e.deadline) do 23:59"
        "election[allow_photos]"                           = "0"
        "election[published]"                              = "1"
        "election[active]"                                 = "1"
        "election[answers_editable]"                       = "1"
        "election[candidacies_visible]"                    = "1"
        "commit"                                           = "Dalej"
    }
    foreach ($e in $($elections | Where-Object {$_.name -eq $el})) {
        $ts = $(get-date -UFormat %s) + $(get-date -format "ffffff")
        $body += [ordered]@{
            "election[seats_attributes][$ts][name]"            = $e.seatname
            "election[seats_attributes][$ts][vacancies_count]" = $e.seats
            "election[seats_attributes][$ts][deadline]"        = "$($e.deadline) 23:59"
            "election[seats_attributes][$ts][description]"     = ""
            "election[seats_attributes][$ts][_destroy]"        = "false"
        }
    }
    
    $s = Invoke-WebRequest -uri "$base/elections" -method POST -websession $rse @commonParams -headers @{
        "Referer" = "$base/elections/new"
        "Origin"  = $base
    } -body $body
    $s.Content -match "`n.*csrf-token""\ content=""(?'token'.*)"".*`n" | Out-Null
    $authToken = $matches.token
    #>
    Write-Output "$($e.name) - $($s.BaseResponse.RequestMessage.RequestUri.AbsoluteUri)"
}