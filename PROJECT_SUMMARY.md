# My iQube: project summary

Personal Flutter (Android) app for my own TVS iQube scooter. It talks to the scooter over Bluetooth LE only: no TVS account, no TVS server, no subscription. Hobby project, not for sale. Code: `~/Downloads/iqube_ble_app` (the README there has the full protocol notes).

## How it talks to the scooter

- GATT service `5456534d-5647-5341-5342-454e544f5251`, notify `5354`, write `5352`.
- 20-byte frames: start byte `5A`/`5B`, DataId, 17 payload bytes, `FF`. Phone-to-scooter payloads are XORed with `0xEB`.
- On connect: `0x53` hello, then a `0x4A` time heartbeat every 2 s (AM/PM byte patterns copied from captures of TVS Connect on my own scooter).
- Connection runs in an Android foreground service, so it works with the app closed. A boot receiver restarts it.
- Known quirk: with the charger plugged in and ignition on, the scooter drops BLE clients after ~1.5 s.

## What is decoded from the scooter

| Data | Where |
|---|---|
| Battery % | DataId `0x13` payload[0] |
| DTE (range) | `0x13` payload[1..2], tenths of km |
| Odometer | `0x10` payload[0..3], tenths of km |
| Ignition | `0x11` payload[3] |
| Handlebar buttons | `0x10` payload[10], ~0.3 s pulse: 01 right/centre (next), 02 left (previous), 03 volume up. Volume down sends nothing |

No charging flag exists: charging = ignition off + battery rising.

## What the app sends to the display

All checked on the real cluster unless noted.

- Calls: `0x43` + caller name, resent every 2 s while ringing.
- Messages (WhatsApp, SMS, Telegram, ...): plain text in `0x53` shows the "Text Message" card.
- Music: song and artist as text in `0x63` (music card). Buttons control the phone's music.
- Location name `0x5c` and weather `0x5d` ("Clouds 29° C"), weather from Open-Meteo.
- Google Maps turn-by-turn: the Maps navigation notification is read, then sent as `5B 4F` + road text and `5A 4E` + distance, time left, distance left and arrow code.
- Phone-side extras (not yet checked on a ride): ride summary when ignition goes off, rain alert, battery health trend (km per % and charge cycles by month).

## App screens

Home (battery, range, ride, last ride, battery health), Rides (GPS ride history and routes), Charging (time to 80%/100%), Settings (pairing, switches for each cluster feature, tests).

## Ideas still open

- Range check against the Maps route, plus charger finder.
- Last parked location ("where is my scooter").
- Phone battery and signal on the cluster.
- Crash/fall detection from the phone's sensors.
- Things that need TVS's cloud (theft alert, geofence while the phone is away, remote commands) are out of scope.

## Working notes

- Build: `flutter build apk --debug`, then `adb install -r`.
- Logs: `adb logcat | grep -E "IQFRAME|IQNOTIF|IQNAV|IQMUSIC|IQRIDE"`.
- Phone setup: grant Notification access to My iQube, allow background power use and Autostart (vivo), allow Google Maps notifications.
- TVS Connect is disabled on both test phones so the two apps don't both send to the scooter.
