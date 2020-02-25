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

    try { $credentials = import-clixml $root/panel.cred }
    catch {
        $credentials = get-credential -Message "Panel login"
        if ($Host.UI.PromptForChoice("Security", "Do you want to save credentials?", @("No", "Yes"), 0)) {
            $credentials | Export-Clixml $root/panel.cred
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

    $s = Invoke-WebRequest -uri "$base/elections/19" -method POST -websession $rse @commonParams -headers @{
        "Referer" = "$base/elections/19/edit"
        "Origin"  = $base
    } -Form @{
        "utf8"                          = "✓"
        "_method"                       = "patch"
        "authenticity_token"            = $authToken
        "election[title]"               = "test"
        "election[region_id]"           = $ID
        "election[instructions]"        = ""
        "election[warning]"             = ""
        "election[allow_photos]"        = 0
        "election[published]"           = 0
        "election[active]"              = 0
        "election[answers_editable]"    = 0
        "election[candidacies_visible]" = 0
        "commit"                        = "Zapisz wybory"
    }

    $s.Content -match "`n.*csrf-token""\ content=""(?'token'.*)"".*`n" | Out-Null
    $authToken = $matches.token

    $s = Invoke-WebRequest -uri "$base/elections/19/voters.csv" @commonParams -WebSession $rse

    $utf8 = [System.Text.Encoding]::GetEncoding(65001)
    $iso88591 = [System.Text.Encoding]::GetEncoding(28591) #ISO 8859-1 ,Latin-1

    $utf8.GetString([System.Text.Encoding]::Convert($utf8, $iso88591, $utf8.GetBytes($s.content))) | Out-File -path "$root\voters-$ID.csv" -NoNewline

    return "$root\voters-$ID.csv"
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

if ($null -ne ($r.InputFields | where-Object value -eq "Logowanie")) {
    if ($Host.UI.PromptForChoice("Error", "It seems that credentials are not working. Delete?", @("No", "Yes"), 0)) {
        remove-item $root/zeus.cred -Force
    }
    break
}

#create election
$output = @()
foreach ($e in (import-csv "$root/zeus-input.csv" -delimiter ',' -encoding "UTF8")) {
    $r = Invoke-WebRequest -uri "$base/elections/new" -WebSession $session -method POST -Body @{
        "trial"                  = "on"
        "election_module"        = "stv"
        "name"                   = $e.Election
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
        "csrfmiddlewaretoken"    = ($r.InputFields | Where-Object name -eq csrfmiddlewaretoken)[0].value
        "linked_polls"           = ""
    } -Headers @{
        "Referer" = "$base/elections/new"
        "Origin"  = $base
    } -ContentType "application/x-www-form-urlencoded; charset=utf-8"

    $electionID = (($r.InputFields | Where-Object name -eq "next").value -split "/")[2]

    $r = Invoke-WebRequest -uri "$base/elections/$electionID/polls/add" @commonParams -WebSession $session -method POST -Body @{
        "name"                      = $e.Poll
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
        "csrfmiddlewaretoken"       = ($r.InputFields | Where-Object name -eq csrfmiddlewaretoken)[0].value
    } -Headers @{
        "Referer" = "$base/elections/$electionID/polls/add"
        "Origin"  = $base
    } -ContentType "application/x-www-form-urlencoded; charset=utf-8"

    $pollID = (($r.links | where-object outerhtml -match "questions")[0].outerhtml -split "/")[4]

    $r = Invoke-WebRequest -uri "$base/elections/$electionID/polls/$pollID/questions/manage" @commonParams -WebSession $session -method GET -Headers @{
        "Referer" = "$base/elections/$electionID/polls/add"
        "Origin"  = $base
    }

    $form = @{
        "form-TOTAL_FORMS"            = 1
        "form-INITIAL_FORMS"          = 1
        "form-MIN_NUM_FORMS"          = 0
        "form-MAX_NUM_FORMS"          = 1000
        "csrfmiddlewaretoken"         = ($r.InputFields | Where-Object name -eq csrfmiddlewaretoken)[0].value
        "form-0-shuffle_answers"      = "on"
        "form-0-eligibles"            = ($e.seats)
        "form-0-has_department_limit" = "on"
        "form-0-department_limit"     = [math]::ceiling(($e.seats / 2))
        "form-0-ORDER"                = 1
    }

    $e.M = $e.M -split ';'
    $e.K = $e.K -split ';'
    $i = 0
    foreach ($c in $e.M) {
        $form["form-0-answer_$i`_0"] = $c
        $form["form-0-answer_$i`_1"] = "M"
        $i++
    }
    foreach ($c in $e.K) {
        $form["form-0-answer_$i`_0"] = $c
        $form["form-0-answer_$i`_1"] = "K"
        $i++
    }

    #add candidates
    $r = Invoke-WebRequest -uri "$base/elections/$electionID/polls/$pollID/questions/manage" @commonParams -WebSession $session -method POST -Form $form -Headers @{
        "Referer" = "$base/elections/$electionID/polls/$pollID/questions/manage"
        "Origin"  = $base
    } -ContentType "multipart/form-data; charset=utf-8"

    $votersPath = get-voters -ID $e.ID

    #add voters
    $r = Invoke-WebRequest -uri "$base/elections/$electionID/polls/$pollID/voters/upload" @commonParams -WebSession $session -method POST -Form @{
        "csrfmiddlewaretoken" = ($r.InputFields | Where-Object name -eq csrfmiddlewaretoken)[0].value
        "csrf_token"          = ($r.InputFields | Where-Object name -eq csrfmiddlewaretoken)[0].value
        "voters_file"         = Get-Item -Path $votersPath #$root/aaa.txt
        "encoding"            = "utf-8"
    } -Headers @{
        "Referer" = "$base/elections/$electionID/polls/$pollID/voters/upload"
        "Origin"  = $base
    } -ContentType "multipart/form-data; charset=utf-8"

    $r = Invoke-WebRequest -uri "$base/elections/$electionID/polls/$pollID/voters/upload" @commonParams -WebSession $session -method POST -Body @{
        "csrfmiddlewaretoken" = ($r.InputFields | Where-Object name -eq csrfmiddlewaretoken)[0].value
        "confirm_p"           = 1
        "encoding"            = "utf-8"
    } -Headers @{
        "Referer" = "$base/elections/$electionID/polls/$pollID/voters/upload"
        "Origin"  = $base
    } -ContentType "application/x-www-form-urlencoded; charset=utf-8"
    $output += [PSCustomObject]@{
        "name" = $e.Election
        "election" = $electionID
        "poll" = $pollID
    }
}
$output | export-csv -Path "$root\out\$(get-date -format "yyyyMMddTHHmmss")-output.csv" -NoTypeInformation -Encoding utf8NoBOM -Delimiter ','
