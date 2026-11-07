# WiFi survey: my home mesh, measured

A WiFi survey of my own home network, measured from **both ends**: what my laptop hears from the access point, and what the access point hears from every device (read from the router's admin API with [vantage](https://github.com/yaseenselemane/vantage)). Network names and MAC addresses are hidden. The raw output is in [`outputs/`](outputs/).

Part of my networking labs: [ping and traceroute](https://github.com/yaseenselemane/ping-and-traceroute) · [nmap](https://github.com/yaseenselemane/nmap-field-notes) · **WiFi survey** · [Packet Tracer](https://github.com/yaseenselemane/cisco-packet-tracer-labs) · [subnet calculator](https://github.com/yaseenselemane/subnet-calculator) · [vantage](https://github.com/yaseenselemane/vantage)

---

## The setup

```
Internet (5G) ──► outdoor 5G unit ──Ethernet──► indoor mesh extender ──WiFi──► every device
                  (router, no WiFi clients)     (2.4 GHz ch 10 + 5 GHz ch 36)
```

The outdoor unit gets the 5G signal and the indoor extender serves all the WiFi clients. They're linked by a **wired backhaul**, so the WiFi doesn't lose half its airtime relaying traffic between mesh nodes.

## What my laptop sees

`netsh wlan show interfaces`:

| | Value |
|---|---|
| Band / channel | 5 GHz, channel 36 |
| Standard | 802.11ac on the laptop (the AP itself supports 802.11ax / WiFi 6) |
| Security | **WPA3-Personal** (SAE with H2E), CCMP cipher |
| Signal | **−35 dBm** (Windows shows 97%) |
| Link rate | 702 Mbps receive, 867 Mbps transmit |

Over 40 seconds the signal stayed between **−36 and −33 dBm**: very stable at this distance.

`netsh wlan show networks mode=bssid` (after asking Windows for a fresh scan):

| Network | Security | Signal | Standard | Band | Channel |
|---|---|---|---|---|---|
| home-5G | WPA3-Personal | 96% | 802.11ax | 5 GHz | 36 |
| home-2.4G | WPA2-Personal | 92% | 802.11ac | 2.4 GHz | 10 |
| *(hidden)* | WPA2-Personal | 91% | 802.11ac | 2.4 GHz | 10 |

No neighbouring networks were in range at all, so there's no interference to fight here. The hidden network on the same channel as the home 2.4 GHz network is almost certainly the mesh system's own management network.

## What the access point hears

Signal as the extender hears each device (via the router's `get_topology` API), strongest first:

| Device | Kind | Signal (dBm) | Band | Rating |
|---|---|---|---|---|
| This laptop | laptop | −53 | 5 GHz | good |
| Device 2 | phone | −57 | 2.4 GHz | good |
| Device 3 | phone | −70 | 2.4 GHz | fair |
| Device 4 | phone | −74 | 2.4 GHz | fair |
| Device 5 | unknown | −79 | 2.4 GHz | poor |
| Device 6 | unknown | −81 | 5 GHz | poor |
| Device 7 | phone | −88 | 5 GHz | very poor |
| Device 8 | unknown | −89 | 5 GHz | very poor |

Rule of thumb: **−60 dBm or better** excellent, **−67** fine for video calls, **−75** fair, **−85 and worse** expect drops and slow speeds.

## Tools

[`wifi-scan.ps1`](wifi-scan.ps1) turns `netsh` output into a table and flags overlapping channels:

```powershell
powershell -File wifi-scan.ps1
powershell -File wifi-scan.ps1 -SelfTest
```

## What I learned

1. **Signal is not the same in both directions.** My laptop hears the access point at −35 dBm, but the access point hears the laptop at −53 dBm, an 18 dB gap (about 60 times less power). Access points transmit louder and have better antennas than laptops or phones. A device can show "full bars" while the AP struggles to hear it, which is why uploads often break first.
2. **dBm is logarithmic.** Every 3 dB halves the power, and every 10 dB divides it by 10. −35 to −89 isn't "54 points weaker". It's millions of times less power.
3. **"Signal %" is Windows' own scale.** The same link reads 97% in `netsh` and −35 dBm in raw RSSI. Compare dBm, not percentages, especially between different devices.
4. **2.4 GHz reaches further, 5 GHz goes faster.** The phones with weaker signals had moved to 2.4 GHz (earlier, from further away, several sat on 5 GHz at −85 to −95 dBm). Lower frequencies pass through walls better, but there are only 3 non-overlapping 2.4 GHz channels (1, 6, 11) and far less speed.
5. **Channel overlap is a 2.4 GHz problem.** 2.4 GHz channels are 5 MHz apart but 20 MHz wide, so neighbouring numbers overlap. 5 GHz channels like 36 don't. With no neighbours in range, channel 10 is fine here. In a block of flats it would matter a lot.
6. **A wired backhaul is the best thing for a mesh.** With a wireless backhaul every packet crosses the air twice, which halves speed. The Ethernet link between the 5G unit and the extender avoids that.
7. **Know your security mode.** The 5 GHz network uses **WPA3** (SAE), which resists offline password guessing. The 2.4 GHz one is still WPA2, kept for older devices, so it's the weaker of the two and the one an attacker would target.
8. **Link rate isn't throughput.** 867 Mbps is the radio's raw rate. Real speed is limited by the 5G internet link (about 28 Mbps measured in [vantage](https://github.com/yaseenselemane/vantage)), so better WiFi wouldn't make the internet faster here.
9. **Windows caches scans.** `netsh wlan show networks` shows the last scan, not now. I asked the WLAN service for a fresh scan (`WlanScan`) before reading it, or the list is incomplete.

## Commands used

```powershell
netsh wlan show interfaces                 # current connection: band, channel, RSSI, rates, security
netsh wlan show networks mode=bssid        # every access point Windows can hear
netsh wlan show drivers                    # what the WiFi card supports (bands, standards, WPA3)
```
