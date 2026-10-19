# Two-instance co-op test for Pacific Drive (PDCoopNet).
# Installs the mod into client1 (host) and client2 (client), runs both for $Seconds, kills them,
# archives the logs into results\<Name> and prints the key lines.
param(
    [string]$Name = "test",
    [string]$Map = "/Game/Maps/RunProto/RB_Garage",
    [int]$Seconds = 240
)
$root = "C:\PDCoop"
$bin = "PenDriverPro\Binaries\Win64"
$roles = @{ client1 = "host`n$Map"; client2 = "client`n127.0.0.1:7777" }

Get-Process PenDriverPro-Win64-Shipping -ErrorAction SilentlyContinue | Stop-Process -Confirm:$false
Start-Sleep 2
foreach ($c in "client1", "client2") {
    $mod = Join-Path $root "$c\$bin\ue4ss\Mods\PDCoopNet"
    Copy-Item "$root\mods-src\PDCoopNet\Scripts\main.lua" "$mod\Scripts\main.lua" -Force
    Set-Content -Encoding ascii "$mod\role.txt" $roles[$c]
    Remove-Item (Join-Path $root "$c\$bin\ue4ss\UE4SS.log") -ErrorAction SilentlyContinue
}
foreach ($c in "client1", "client2") {
    $exe = Join-Path $root "$c\$bin\PenDriverPro-Win64-Shipping.exe"
    Start-Process $exe -ArgumentList "-NotInstalled", "-windowed", "-ResX=960", "-ResY=540", "-log" -WorkingDirectory (Split-Path $exe) | Out-Null
    Start-Sleep 8
}
$deadline = (Get-Date).AddSeconds($Seconds)
while ((Get-Date) -lt $deadline) {
    Start-Sleep 5
    if (@(Get-Process PenDriverPro-Win64-Shipping -ErrorAction SilentlyContinue).Count -lt 2) { Write-Output "WARNING: a game process exited early"; break }
}
Get-Process PenDriverPro-Win64-Shipping -ErrorAction SilentlyContinue | Stop-Process -Confirm:$false
Start-Sleep 3

$out = Join-Path $root "results\$Name"
New-Item -ItemType Directory -Force $out | Out-Null
foreach ($c in "client1", "client2") {
    Copy-Item (Join-Path $root "$c\$bin\ue4ss\UE4SS.log") "$out\$c-UE4SS.log" -ErrorAction SilentlyContinue
    Copy-Item (Join-Path $root "$c\PenDriverPro\Saved\Logs\PenDriverPro.log") "$out\$c-PenDriverPro.log" -ErrorAction SilentlyContinue
    Set-Content -Encoding ascii (Join-Path $root "$c\$bin\ue4ss\Mods\PDCoopNet\role.txt") "off"
}
function Get-Status($file) {
    Select-String -Path $file -Pattern "PDNET\|.*map=RB_Garage" | ForEach-Object { $_.Line }
}
function Get-Pos($line, $pattern) {
    if ($line -match $pattern) { return $Matches[1] } return $null
}
$hostLines = @(Get-Status "$out\client1-UE4SS.log")
$clientLines = @(Get-Status "$out\client2-UE4SS.log")
$checks = [ordered]@{}
$lastC = if ($clientLines.Count) { $clientLines[-1] } else { "" }
$lastH = if ($hostLines.Count) { $hostLines[-1] } else { "" }
$checks["client connected to host (serverConn=yes)"] = $lastC -match "serverConn=yes"
$checks["host has 2 PlayerControllers"] = $lastH -match "\|pcs=2\|"
$checks["client possesses own PDP_MainCharacter (local, role=2)"] = $lastC -match "PDP_MainCharacter_C:\d+\[local\|role=2"
$checks["client sees host character (role=1)"] = $lastC -match "PDP_MainCharacter_C:\d+\[none\|role=1"
$checks["host sees remote PDP_MainCharacter"] = $lastH -match "PDP_MainCharacter_C:\d+\[remote\|role=3"
$checks["client has exactly one player car"] = ([regex]::Matches($lastC, "BP_PlayerCarNew_C:")).Count -eq 1
$checks["client car is the replicated one (role=1)"] = $lastC -match "BP_PlayerCarNew_C:\d+\[none\|role=1"
$remote = @($hostLines | ForEach-Object { Get-Pos $_ "PDP_MainCharacter_C:\d+\[remote\|role=3\|([-\d,]+)" } | Where-Object { $_ } | Select-Object -Unique)
$checks["client walking moves its character on the host (>=3 distinct positions)"] = $remote.Count -ge 3
$hostPos = @($clientLines | ForEach-Object { Get-Pos $_ "PDP_MainCharacter_C:\d+\[none\|role=1\|([-\d,]+)" } | Where-Object { $_ } | Select-Object -Unique)
$checks["host movement visible on client (>=2 distinct positions)"] = $hostPos.Count -ge 2
# car: host drives, client rides
$hostLog = "$out\client1-UE4SS.log"; $clientLog = "$out\client2-UE4SS.log"
$checks["client SEAT command reached host and seated the passenger"] = [bool](Select-String -Path $hostLog -Pattern "\] SEAT .* attached to BP_PlayerCarNew_C" -Quiet)
$checks["host is driving the car (host possesses car)"] = [bool](Select-String -Path $hostLog -Pattern "DRIVE t=.*hostPossessesCar=true" -Quiet)
$moved = @(Select-String -Path $hostLog -Pattern "DRIVE t=\d+ mode=(\w+) .*movedFromStart=(\d+)" | ForEach-Object { [int]$_.Matches[0].Groups[2].Value })
$maxMoved = if ($moved.Count) { ($moved | Measure-Object -Maximum).Maximum } else { 0 }
$mode = (Select-String -Path $hostLog -Pattern "DRIVE t=\d+ mode=(\w+)" | Select-Object -Last 1 | ForEach-Object { $_.Matches[0].Groups[1].Value })
$checks["car moved on host > 500 uu (max $maxMoved, mode=$mode)"] = $maxMoved -gt 500
$checks["host sees remote character attached to the car"] = [bool](Select-String -Path $hostLog -Pattern "PDP_MainCharacter_C:\d+\[remote\|role=3\|[^\]]*\|att=" -Quiet)
$ride = @(Select-String -Path $clientLog -Pattern "RIDE parent=BP_PlayerCarNew_C\S* charLoc=\S+ carLoc=(\S+) charToCar=(\d+)")
$checks["client character attached to the car on the client"] = $ride.Count -gt 0
$carPos = @($ride | ForEach-Object { $_.Matches[0].Groups[1].Value } | Select-Object -Unique)
$checks["client sees the car move while riding (>=3 distinct car positions, got $($carPos.Count))"] = $carPos.Count -ge 3
$gap = if ($ride.Count) { ($ride | ForEach-Object { [int]$_.Matches[0].Groups[2].Value } | Measure-Object -Maximum).Maximum } else { 99999 }
$checks["passenger stays with the car on the client (max char-to-car $gap uu < 400)"] = $gap -lt 400

$pass = 0
Write-Output "===== CHECKS"
foreach ($k in $checks.Keys) {
    $r = if ($checks[$k]) { $pass++; "PASS" } else { "FAIL" }
    Write-Output "$r  $k"
}
Write-Output "SUMMARY: $pass/$($checks.Count) checks passed"

foreach ($c in "client1", "client2") {
    Write-Output "===== $c events"
    Select-String -Path "$out\$c-UE4SS.log" -Pattern "PDCoopNet\] (GAMEMODE|SPAWN|DEDUPE|client |host |CLIENT-LOCAL|SEAT|CMD|DRIVE|.* error:)" | ForEach-Object { $_.Line.Substring([Math]::Min(30, $_.Line.Length)) }
    Write-Output "===== $c last status"
    Select-String -Path "$out\$c-UE4SS.log" -Pattern "PDNET\|" | Select-Object -Last 3 | ForEach-Object { $_.Line.Substring([Math]::Min(30, $_.Line.Length)) }
    Write-Output "===== $c engine errors (net/player/fatal)"
    Select-String -Path "$out\$c-PenDriverPro.log" -Pattern "Fatal|NetworkFailure|TravelFailure|LogPlayerController: Error|Accessed None|Join succeeded|Welcomed" | Select-Object -Last 8 | ForEach-Object { $_.Line.Substring(0, [Math]::Min(260, $_.Line.Length)) }
}
