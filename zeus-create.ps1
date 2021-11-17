#Requires -Version 6

$commonParams = @{
    #"Proxy" = ""
    #"ProxyUseDefaultCredential" = $true
}

function Get-Voters {
    [CmdletBinding()]
    param (
        $ID
    )

    $base = "https://panel.partiarazem.pl"

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

    $s = Invoke-WebRequest -uri "$base/elections/$ID/voters.csv" @commonParams -WebSession $rse

    $utf8 = [System.Text.Encoding]::GetEncoding(65001)
    $iso88591 = [System.Text.Encoding]::GetEncoding(28591) #ISO 8859-1 ,Latin-1

    $utf8.GetString([System.Text.Encoding]::Convert($utf8, $iso88591, $utf8.GetBytes($s.content))) | Out-File -path "$root\temp\voters-$ID.csv" -NoNewline

    return "$root\temp\voters-$ID.csv"
}

$base = "https://zeus.int.partiarazem.pl"
#$base = "https://zeus.gko.mj12.pl"
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

if ($null -ne ($r.InputFields | where-Object value -eq "Logowanie")) {
    if ($Host.UI.PromptForChoice("Error", "It seems that credentials are not working. Delete?", @("No", "Yes"), 0)) {
        remove-item "$root\$($base -replace "https://").cred" -Force
    }
    break
}

#create election
$output = @()

$elections = import-csv "$root/zeus-input.csv" -delimiter ',' -encoding "UTF8"

$no = 0
$elTemp = @()
foreach ($e in $elections) {
    $can = @()
    if ($e.m -eq "") { $m = @() } else { $m = $($e.M -split ';') }
    if ($e.k -eq "") { $k = @() } else { $k = $($e.K -split ';') }
    $can += $m
    $can += $k
    $s = [math]::floor(($e.seats / 2))
    $maxLegalMandates = $([Math]::Min($([Math]::Min($m.count, $k.count) * 2 + 1 ), $can.count))

    $quotaM = $($m.count -ge $s)
    $quotaK = $($k.count -ge $s)
    $quotaA = $($can.count -ge $e.seats)

    if ($($elections | where-object { $_.election -eq $e.election }).count -gt 1) {
        $electionName = "$($e.Election) $($e.poll)"
    }
    else {
        $electionName = $e.Election
    }
    if (-not ($quotaM -and $quotaK -and $quotaA)) {
        if ($maxLegalMandates -gt 0) {

            write-output @"
Kandydatury kobiece: $($k.count)
Kandydatury męskie: $($m.count)
Ilość mandatów: $($e.seats)
Maksymalna legalna liczba mandatów: $maxLegalMandates
"@
        }
        $e.seats = read-host "podaj nową ilość mandatów (0 by anulować wybory): "

        if ($e.seats -eq 0) {
            #dowolny warunek niespełniony, odrzucamy wybory
            $no++
            Write-Output @"
`n`n**$(get-date -Format "U-\K\KW-yyyy-MM-dd")-$no**
$electionName nie odbędą się ze względu na niedostateczną liczbę kandydatur.

Odwołania można składać do $($(get-date).AddDays(8).ToShortDateString()).
`n---`n
"@
            continue
        }
        else {
            $no++
            Write-Output @"
`n`n**$(get-date -Format "U-\K\KW-yyyy-MM-dd")-$no**
Ze względu na niedostateczną liczbę zgłoszeń, na podstawie Art. 15 pkt. 12 Statutu Partii, Krajowa Komisja Wyborcza ogłasza, że $electionName odbędą się z liczbą mandatów obniżoną do $($e.Seats).

Odwołania można składać do $($(get-date).AddDays(8).ToShortDateString()).
`n---`n
"@
        }

    }
    if ($can.count -eq $e.seats) {
        #tyle osób co miejsc, wyniki wyborów bez głosowania
        $no++
        write-output @"
**$(get-date -Format "U-\K\KW-yyyy-MM-dd")-$no**
Na podstawie Art. 15 pkt. 11 Statutu Partii, Krajowa Komisja Wyborcza ogłasza że $electionName odbywają się bez przeprowadzania głosowania ze względu na liczbę kandydatur równą liczbie miejsc do obsadzenia i spełniony parytet.
Wybrane zostają następujące osoby:

$($can | Sort-Object {Get-Random} | ForEach-Object {write-output "- $_`n"})

Ze względu na brak głosowania, lista znajduje się w losowej kolejności.

Odwołania można składać do $($(get-date).AddDays(8).ToShortDateString()).
`n---`n
"@
    }
    else {
        #przeprowadź wybory
        $eltemp += $e
    }
}
$elections = $elTemp
#<#
foreach ($election in ($elections.Election | select-object -unique)) {
    $e = $elections | where-object election -eq $election | select-object -first 1

    #Create election

    $r = Invoke-WebRequest -uri "$base/elections/new" -WebSession $session -method POST -Body @{
        "election_module"        = "stv"
        "name"                   = "$($e.Election)"
        "description"            = $e.Election
        "departments"            = "M`nK"
        "voting_starts_at_0"     = $e.Start
        "voting_starts_at_1"     = "00:00"
        "voting_ends_at_0"       = $e.End
        "voting_ends_at_1"       = "23:59"
        "trustees"               = "Partyjna Komisja Wyborcza, razem.pkw@gmail.com"
        "help_email"             = "pkw@partiarazem.pl"
        "help_phone"             = "[skontaktuj się z ZO]"
        "communication_language" = "pl"
        "cast_consent_text"      = ""
        "csrfmiddlewaretoken"    = $csrfRegex.matches(($r.Content -split "`n" | select-string "csrfmiddlewaretoken")[0]).captures.groups[1].value
        "linked_polls"           = ""
    } -Headers @{
        "Referer" = "$base/elections/new"
        "Origin"  = $base
    } -ContentType "application/x-www-form-urlencoded; charset=utf-8"

    $electionID = (($r.InputFields | Where-Object name -eq "next").value -split "/")[2]

    #create polls
    $votersPath = get-voters -ID $e.ID

    foreach ($poll in $($elections | where-object election -eq $election)) {
        $r = Invoke-WebRequest -uri "$base/elections/$electionID/polls/add" @commonParams -WebSession $session -method POST -Body @{
            "name"                      = $poll.poll
            "jwt_file"                  = ""
            "jwt_issuer"                = ""
            "jwt_public_key"            = ""
            "oauth2_type"               = "google"
            "oauth2_client_type"        = "public"
            "oauth2_client_id"          = ""
            "oauth2_client_secret"      = ""
            "oauth2_code_url"           = "https://accounts.google.com/o/oauth2/auth"
            "oauth2_exchange_url"       = "https://accounts.google.com/o/oauth2/token"
            "oauth2_confirmation_url"   = "https://www.googleapis.com/oauth2/v1/userinfo"
            "shibboleth_constraints"    = ""
            "google_code_url"           = "https://accounts.google.com/o/oauth2/auth"
            "google_exchange_url"       = "https://accounts.google.com/o/oauth2/token"
            "google_confirmation_url"   = "https://www.googleapis.com/oauth2/v1/userinfo"
            "facebook_code_url"         = "https://www.facebook.com/dialog/oauth"
            "facebook_exchange_url"     = "https://graph.facebook.com/oauth/access_token"
            "facebook_confirmation_url" = "https://graph.facebook.com/v2.2/me"
            "csrfmiddlewaretoken"       = $csrfRegex.matches(($r.Content -split "`n" | select-string "csrfmiddlewaretoken")[0]).captures.groups[1].value
        } -Headers @{
            "Referer" = "$base/elections/$electionID/polls/add"
            "Origin"  = $base
        } -ContentType "application/x-www-form-urlencoded; charset=utf-8"

        $pollID = (($r.links | where-object outerhtml -match "questions")[-1].href -split "/")[4]

        $r = Invoke-WebRequest -uri "$base/elections/$electionID/polls/$pollID/questions/manage" @commonParams -WebSession $session -method GET -Headers @{
            "Referer" = "$base/elections/$electionID/polls/add"
            "Origin"  = $base
        }

        $form = @{
            "form-TOTAL_FORMS"            = 1
            "form-INITIAL_FORMS"          = 1
            "form-MIN_NUM_FORMS"          = 0
            "form-MAX_NUM_FORMS"          = 1000
            "csrfmiddlewaretoken"         = $csrfRegex.matches(($r.Content -split "`n" | select-string "csrfmiddlewaretoken")[0]).captures.groups[1].value
            "form-0-shuffle_answers"      = "on"
            "form-0-eligibles"            = ($poll.seats)
            "form-0-has_department_limit" = "on"
            "form-0-department_limit"     = [math]::ceiling(($poll.seats / 2))
            "form-0-ORDER"                = 1
        }

        $poll.M = $poll.M -split ';'
        $poll.K = $poll.K -split ';'
        $i = 0
        foreach ($c in $poll.M) {
            $form["form-0-answer_$i`_0"] = $c
            $form["form-0-answer_$i`_1"] = "M"
            $i++
        }
        foreach ($c in $poll.K) {
            $form["form-0-answer_$i`_0"] = $c
            $form["form-0-answer_$i`_1"] = "K"
            $i++
        }

        #add candidates
        $r = Invoke-WebRequest -uri "$base/elections/$electionID/polls/$pollID/questions/manage" @commonParams -WebSession $session -method POST -Form $form -Headers @{
            "Referer" = "$base/elections/$electionID/polls/$pollID/questions/manage"
            "Origin"  = $base
        } -ContentType "multipart/form-data; charset=utf-8"

        #add voters

        $r = Invoke-WebRequest -uri "$base/elections/$electionID/polls/$pollID/voters/upload" @commonParams -WebSession $session -method POST -Form @{
            "csrfmiddlewaretoken" = $csrfRegex.matches(($r.Content -split "`n" | select-string "csrfmiddlewaretoken")[0]).captures.groups[1].value
            "csrf_token"          = $csrfRegex.matches(($r.Content -split "`n" | select-string "csrfmiddlewaretoken")[0]).captures.groups[1].value
            "voters_file"         = Get-Item -Path $votersPath #$root/aaa.txt
            "encoding"            = "utf-8"
        } -Headers @{
            "Referer" = "$base/elections/$electionID/polls/$pollID/voters/upload"
            "Origin"  = $base
        } -ContentType "multipart/form-data; charset=utf-8"

        $r = Invoke-WebRequest -uri "$base/elections/$electionID/polls/$pollID/voters/upload" @commonParams -WebSession $session -method POST -Body @{
            "csrfmiddlewaretoken" = $csrfRegex.matches(($r.Content -split "`n" | select-string "csrfmiddlewaretoken")[0]).captures.groups[1].value
            "confirm_p"           = 1
            "encoding"            = "utf-8"
        } -Headers @{
            "Referer" = "$base/elections/$electionID/polls/$pollID/voters/upload"
            "Origin"  = $base
        } -ContentType "application/x-www-form-urlencoded; charset=utf-8"
        $output += [PSCustomObject]@{
            "name"       = $e.Election
            "pollName"   = $e.poll
            "election"   = $electionID
            "poll"       = $pollID
        }
    }
}
$output | export-csv -Path "$root\out\$(get-date -format "yyyyMMddTHHmmss")-output.csv" -NoTypeInformation -Encoding utf8NoBOM -Delimiter ','
#>

########## end election form in panel ####################
<#
try { $credentials = import-clixml "$root\panel.partiarazem.pl.cred" }
catch {
    $credentials = get-credential -Message "Panel login"
    if ($Host.UI.PromptForChoice("Security", "Do you want to save credentials?", @("No", "Yes"), 0)) {
        $credentials | Export-Clixml "$root\panel.partiarazem.pl.cred"
    }
}

$s = Invoke-WebRequest -uri "https://panel.partiarazem.pl" -method GET -SessionVariable "rse" @commonParams -headers @{
    "Referer" = "https://panel.partiarazem.pl/members/sign_in"
    "Origin"  = "https://panel.partiarazem.pl"
}
$s.Content -match "`n.*csrf-token""\ content=""(?'token'.*)"".*`n" | Out-Null
$authToken = $matches.token
$s = Invoke-WebRequest -uri "https://panel.partiarazem.pl/members/sign_in" -method POST -websession $rse @commonParams -headers @{
    "Referer" = "https://panel.partiarazem.pl/members/sign_in"
    "Origin"  = "https://panel.partiarazem.pl"
} -body @{
    "utf8"               = "✓"
    "authenticity_token" = $authToken
    "member[email]"      = $credentials.UserName
    "member[password]"   = $credentials.GetNetworkCredential().Password
    "commit"             = "Zaloguj się"
}

$s.Content -match "`n.*csrf-token""\ content=""(?'token'.*)"".*`n" | Out-Null
$authToken = $matches.token

foreach ($e in $(import-csv "$root/zeus-input.csv" -delimiter ',' -encoding "UTF8")) {
    Write-Output "closing " + $e.Election
    $s = Invoke-WebRequest -uri "https://panel.partiarazem.pl/elections/$($e.ID)" -method PUT -websession $rse @commonParams -headers @{
        "Referer" = "https://panel.partiarazem.pl/elections"
        "Origin"  = "https://panel.partiarazem.pl"
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
#>