# wifi-scan.ps1 - turn `netsh wlan show networks mode=bssid` into a table, and say which channels are crowded.
# Usage:  powershell -File wifi-scan.ps1            (scan what Windows can see now)
#         powershell -File wifi-scan.ps1 -SelfTest
param([switch]$SelfTest)

function ConvertFrom-Netsh([string[]]$lines) {
  $rows = @(); $cur = $null; $ssid = ''; $auth = ''
  foreach ($l in $lines) {
    if ($l -match '^SSID \d+ : ?(.*)') { $ssid = $Matches[1].Trim(); $cur = $null }
    elseif ($l -match '^\s+Authentication\s+: (.*)') { $auth = $Matches[1].Trim() }
    elseif ($l -match '^\s+BSSID \d+\s+: (.*)') { $cur = [ordered]@{ SSID = $(if ($ssid) { $ssid } else { '(hidden)' }); Auth = $auth; BSSID = $Matches[1].Trim() }; $rows += $cur }
    elseif ($cur -and $l -match '^\s+Signal\s+: (\d+)%') { $cur.Signal = [int]$Matches[1] }
    elseif ($cur -and $l -match '^\s+Radio type\s+: (.*)') { $cur.Radio = $Matches[1].Trim() }
    elseif ($cur -and $l -match '^\s+Band\s+: (.*)') { $cur.Band = $Matches[1].Trim() }
    elseif ($cur -and $l -match '^\s+Channel\s+: (\d+)') { $cur.Channel = [int]$Matches[1] }
  }
  $rows | ForEach-Object { [pscustomobject]$_ }
}

# 2.4 GHz channels are 5 MHz apart but 20 MHz wide, so only 1, 6 and 11 don't overlap.
function Get-Overlap([int]$a, [int]$b) { if ($a -le 14 -and $b -le 14) { [math]::Abs($a - $b) -lt 5 } else { $a -eq $b } }

if ($SelfTest) {
  $sample = @(
    'SSID 1 : home', '    Authentication          : WPA3-Personal', '    BSSID 1                 : aa:bb:cc:00:00:01',
    '         Signal             : 96%', '         Radio type         : 802.11ax', '         Band               : 5 GHz', '         Channel            : 36',
    'SSID 2 : ', '    Authentication          : WPA2-Personal', '    BSSID 1                 : aa:bb:cc:00:00:02',
    '         Signal             : 40%', '         Band               : 2.4 GHz', '         Channel            : 10')
  $r = @(ConvertFrom-Netsh $sample)
  if ($r.Count -ne 2 -or $r[0].Channel -ne 36 -or $r[0].Signal -ne 96 -or $r[1].SSID -ne '(hidden)' -or $r[1].Auth -ne 'WPA2-Personal') { throw "parse failed: $($r | Out-String)" }
  if (-not (Get-Overlap 10 11) -or (Get-Overlap 1 6) -or (Get-Overlap 36 40)) { throw "overlap rule failed" }
  "self-test passed"; return
}

$nets = @(ConvertFrom-Netsh (netsh wlan show networks mode=bssid))
$nets | Sort-Object Band, Channel | Format-Table SSID, Auth, Signal, Radio, Band, Channel -AutoSize
foreach ($n in $nets) {
  $others = @($nets | Where-Object { $_ -ne $n -and (Get-Overlap $_.Channel $n.Channel) })
  "{0,-20} ch {1,-3} overlaps with {2} other access point(s)" -f $n.SSID, $n.Channel, $others.Count
}
