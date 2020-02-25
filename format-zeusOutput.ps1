[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $file = ".\out\20210120T204536-Warszawa2021-Rada-Okręgu-wynik-out.csv"
    , [Parameter()]
    [string]
    $title = $file
)

$in = $(Get-content $file -raw) -replace "`r`n", "`n"

write-output "# $title`n"
$results = (([regex]"(?s)Results:`n(?<results>.*)").Matches($in).groups | Where-Object { $_.name -eq "results" }).value

write-output "## Wyniki`n`n|Kandydatka|Runda|Głosów|`n|:---|:---:|:---|"

foreach ($winner in ($results -replace "`r`n", "`n" -split "`n")) {
    if ([string]::IsNullOrWhiteSpace($winner)) { continue }
    $winnerMatch = ([regex]"\('(?<winner>.*)', (?<round>\d*), (?<votes>[\d.]+)\)").Matches($winner)[0].groups
    write-output "|$($winnerMatch['winner'])|$($winnerMatch['round'])|$($winnerMatch['votes'])|"
}

$rounds = ([regex]"(?s)@ROUND.+?(?=@ROUND|Results:)").Matches($in).Value
foreach ($round in $rounds) {
    $round = $round -replace "`r`n", "`n" -split "`n"
    $round[0] = $round[0] -replace "@ROUND", "RUNDA"
    $people = $round[1]
    If ($people -match "^.COUNT") { Write-Output "## $($round[0])`n" }
    else { write-output "## $($round[0]) - Dogrywka`n" }
    write-output "|Kandydatka|Głosy|Działanie|`n|---|---|---|"
    $round[-2] -match "^(?<action>[^ ]*) (?<person>.*) = (?<votes>.*)" | Out-Null
    $people -replace ".COUNT " -replace "~ZOMBIES " -split ";" | sort-object | ForEach-Object {
        $action = ""
        $pers = $_ -split " = "
        if ($pers[0] -eq $matches["person"]) {
            switch ($matches['action']) {
                "+ELECT" { $action = "WYBIERZ"; break }
                "!QUOTA" { $action = "KWOTA"; break }
                "-ELIMINATE" { $action = "ODRZUĆ"; break }
            }
        }
        Write-Output $("|$($pers[0])|$($pers[1])|$action|")
    }
    write-output ""
}