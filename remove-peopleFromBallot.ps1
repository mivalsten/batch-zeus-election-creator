[CmdletBinding()]
param (
    [Parameter(
        Mandatory = $false,
        ValueFromPipeline = $false)
    ][string]$file = (Get-ChildItem -path $PSScriptRoot -Filter "*.csv" | Out-GridView -PassThru | Select-Object -first 1).versionInfo.filename,
    [Parameter(
        Mandatory = $false,
        ValueFromPipeline = $false)
    ][string]$zeusPath = "/home/gko/zeus/zeus",
    [Alias("q")]
    [Parameter(
        Mandatory = $false,
        ValueFromPipeline = $false)
    ][string]$quota = 0,
    [Alias("s")]
    [Parameter(
        Mandatory = $false,
        ValueFromPipeline = $false)
    ][string]$seats = 0,
    [Parameter(
        Mandatory = $true,
        ValueFromPipeline = $false)
    ]$personToRemove
)
Import-Module Microsoft.PowerShell.GuiTools
$OutputEncoding = [console]::InputEncoding = [console]::OutputEncoding = New-Object System.Text.UTF8Encoding

$filepath = Split-Path $file
$filename = Split-Path $file -LeafBase
$extension = Split-Path $file -Extension
$date = $(get-date -f "yyyyMMddTHHmmss")
$constituenciesPath = join-path -path "$filepath" -ChildPath "$date-$filename-constituencies$extension"
$ballotsPath = Join-Path -Path "$filepath" -ChildPath "$date-$filename-ballots$extension"
$outpath = Join-Path "$filepath" "$date-$filename-out"

write-output "filepath: $filepath"
write-output "filename: $filename"
write-output "extension: $extension"
write-output "constituenciesPath: $constituenciesPath"
write-output "ballotsPath: $ballotsPath"
write-output "outpath: $outpath"
#>
$fileContent = Get-Content $file -Encoding UTF8
#assume that if the file is not raw export from Zeus it's ballot file
if ($fileContent[0] -match "Nazwa wybor.w") { $skip = $true }
else { $skip = $false }
$constituencies = @()
foreach ($line in $fileContent) {
    if ($line -match "Nazwa wybor.w") { $title = $($line -split ',')[1] }
    if ($line -match "Nazwa g.osowania") { $title += " - $($($line -split ',')[1])" }
    if ($line -match "Karty do g.osowania") {
        $skip = $false
        Write-Output "stopped skipping"
        continue
    }
    if ($skip) { continue }
    $votees = $line -split ',' | Where-Object { $_ -notin $personToRemove }
    if ($votees.count -gt 0) {
        $votees -join ',' | out-file $ballotsPath -Encoding UTF8 -Append
        $constituencies += $($votees | where-object { $_ -notin $constituencies })
    }
}


$m = @()
$k = @()
$x = @()
$constituencies
foreach ($votee in $constituencies) {
    switch ($votee[-2, -1] -join "") {
        ":M" { $m += $votee; break }
        ":K" { $k += $votee; break }
        ":X" { $x += $votee; break }
        Default {}
    }
}
$m -join "," | Out-File -Encoding UTF8 -FilePath $constituenciesPath
$k -join "," | Out-File -Encoding UTF8 -FilePath $constituenciesPath -append
$x -join "," | Out-File -Encoding UTF8 -FilePath $constituenciesPath -append

Push-Location
Set-Location $zeusPath
New-Item -Path "$filepath\out\" -ItemType "directory" -ErrorAction SilentlyContinue | Out-Null

C:\Users\grzeg\AppData\Local\Programs\Python\Python310\python.exe -m stv.stv -b $ballotsPath -c $constituenciesPath --separate-quota $quota -s $seats | out-file "$outpath.csv"
Get-Content "$outpath.csv"

& "$psscriptroot/format-zeusOutput.ps1" -file "$outpath.csv" -title "$title" | Tee-Object "$outpath.md" | pandoc -s -o "$outpath.pdf"
Pop-Location
#>