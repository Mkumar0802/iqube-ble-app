# My iQube BLE

An unofficial, open-source Android app (Flutter) that talks to **your own**
TVS iQube scooter directly over Bluetooth LE. No TVS account, login, server
or subscription is involved.

It reads battery %, range (DTE), odometer and ignition from the scooter, and
sends calls, messages, music, weather and Google Maps turn-by-turn directions
to the iQube's cluster. Hobby project, tested on one scooter.

> [!WARNING]
> **For educational purposes only. Non-profit, no commercial use.**
>
> - Unofficial: not affiliated with, endorsed by or supported by TVS Motor
>   Company. "TVS", "iQube" and "TVS Connect" are trademarks of their owners.
> - Experimental: the app sends data to a real vehicle. Use it only with your
>   own vehicle, entirely at your own risk. It may affect your vehicle
>   warranty.
> - Never use your phone while riding.
> - Provided as-is, without any warranty. The author accepts no liability
>   for any damage, injury or loss.
>
> By using this software you agree to the [Terms of Use](TERMS.md) and the
> [license](LICENSE).

## License

[PolyForm Noncommercial License 1.0.0](LICENSE): free to use, study, change
and share for personal, educational and other non-commercial purposes.
Commercial use is not permitted. Because it bans commercial use, this is a
"source-available" license rather than an OSI "open source" one.

## Contributing

Issues and pull requests are welcome, especially:

- Frames that are still unknown (speed, trip meters), with `IQFRAME` logcat
  captures from your scooter.
- Results from other iQube variants or cluster software versions.
- Anything in "not yet checked" below that you've tested on a real ride.

Please don't include your scooter's MAC address, VIN or location in logs you
post.

## Where the protocol came from

The frame formats were worked out from Bluetooth captures between TVS
Connect and the author's own scooter, plus reading the public TVS Connect
APK for compatibility. Two small lookup tables in
`lib/services/maps_navigation.dart` (cluster arrow codes, instruction to
maneuver id) are compatibility data recovered that way.

The official app doesn't hardcode the GATT UUIDs: they're fetched from TVS's
backend after login and cached per model. For the iQube they are now known
(below). For another TVS model, find yours with your own phone and vehicle:

### Option A — BLE Explorer screen (included, easiest)
1. `flutter run` this app on your phone.
2. Tap **"Open BLE Explorer"**.
3. Scan, tap your vehicle in the list.
4. It connects, lists every GATT service + characteristic your vehicle
   advertises (with read/write/notify flags), and auto-subscribes to every
   notify-capable characteristic, printing live hex + ASCII as data arrives.
5. Turn the ignition on/off, watch the charge %, move the vehicle, etc. on
   your own bike and see which characteristic's bytes change — that's your
   telemetry channel. Note its Service UUID and Characteristic UUID.

### Option B — Android Bluetooth HCI snoop log
1. Enable Developer Options → "Enable Bluetooth HCI snoop log".
2. Toggle Bluetooth off/on.
3. Open the official TVS Connect app and let it connect to your vehicle.
4. Disable the snoop log toggle (flushes the file) or take a bug report.
5. Pull `btsnoop_hci.log` and open it in Wireshark — filter on your
   vehicle's MAC address, look at the ATT protocol packets for the real
   Service/Characteristic UUIDs and the exact bytes exchanged.

Once you have real UUIDs, paste them into `lib/ble/gatt_constants.dart` and
switch to using `TelemetryScreen` for a cleaner parsed view.

## What's included

The app now has four tabs:

- **Home**: connection status, battery %, estimated Eco/Power range, start/end
  ride, and lifetime ride totals.
- **Rides**: ride history recorded from phone GPS (distance, time, top/avg
  speed, battery used, route map) and your real km-per-% efficiency.
- **Charging**: charging status and time to 80% / 100%, based on how fast
  the battery % rises.
- **Settings**: pair/forget the scooter, auto-connect, notifications on the
  cluster (experimental), range and charge defaults, and developer tools.

What is decoded from the scooter (see `lib/ble/gatt_constants.dart`):

- Service `5456534d-5647-5341-5342-454e544f5251`, notify `5354`, write `5352`.
- 20-byte frames: `5A`/`5B`, DataId, 17 payload bytes, `FF`. Payloads from
  the phone are XORed with `0xEB`.
- On connect the app sends the 0x53 hello, then a 0x4A time heartbeat every
  2 s, the same sequence TVS Connect uses.
- Battery % = first payload byte of DataId 0x13.
- DTE (cluster range) = DataId 0x13 payload[1..2], big-endian tenths of a km.
- Odometer = DataId 0x10 payload[0..3], big-endian tenths of a km.
- Time heartbeat (0x4A): `30 78 00 02 HH MM SS 00 00 05` in the morning,
  `43 78 00 02 HH MM SS 01 10 04` in the afternoon (TVS Connect captures).
  Byte 7 looks like the PM flag. Hours past 12 are sent on a 12-hour clock
  (01:21 PM checked on the cluster).
- Ignition = DataId 0x11 payload[3] (01 on, 00 off). The scooter keeps
  streaming while charging with the ignition off. It sends no separate charging flag.
- Logs every changed frame to logcat: `adb logcat | grep IQFRAME`.

Range is an estimate (battery % x configured full range) until 10% of
battery has been used across recorded rides. After that it uses your
measured km per %. Cluster notifications are plain ASCII text frames (max 17 chars), checked on
the cluster: 0x43 + caller name = "Incoming call..." popup, 0x53 = "Text
Message" card. 0x63 is the music card. Calls come from the phone-state
broadcast as soon as the phone rings, because the dialer's notification can
arrive only after the call ends.

Google Maps directions on the cluster use TVS Connect's navigation frames
(from `BleNavigationSendData.byteArrayForNavigation`), read from Maps'
navigation notification. No TVS account or subscription is involved:

- `5B 4F` + instruction text (17 chars), then 400 ms later
- `5A 4E` + metres to turn (2 bytes) + minutes left (2) + metres left (3) +
  arrow code + 1/2 (text fits in 17 chars or not) + zeros.
- Arrow codes are the cluster's own table, not raw Mappls ids: the app maps
  the instruction to a Mappls id and then through TVS's `getPictogramForU725`
  table. Checked on the cluster: 0 left, 2 slight left, 57 straight,
  19 U-turn, 27-33 roundabout exits.
- The cluster works out the ETA itself and shows whole km left. The road
  name isn't shown on this screen. Maps' first step ("Head northwest") has no
  distance, so it shows 0 m.
- Settings > Test directions steps through the arrow codes with the
  distance set to the code number.

## What's NOT included (by design)

- No TVS login/account flow.
- No calls to any TVS backend API.
- No attempt to pull the UUIDs from TVS's servers automatically.

## Running it

```bash
flutter pub get
flutter run   # with your Android phone connected via USB + USB debugging on
```

Needs Flutter SDK installed. Tested target: Android (BLE on iOS works too
with `flutter_blue_plus`, but permission setup in `Info.plist` isn't
included here yet).

Other cluster features:

- **Music**: the playing song (any app with a media session) goes to the
  music card as plain text in 0x63 (checked on the cluster). The handlebar
  buttons show up for ~0.3 s in the 0x10 frame, payload[10]. Checked one
  button at a time: right and centre both 01 (next), left 02 (previous),
  volume up 03, volume down sends nothing. 05 showed up in earlier tests
  (used for play/pause). 04 is TVS's voice assistant button. The iQube doesn't send the 0x6B music frame that
  other TVS models use.
- **Ride summary**: ignition on to off (0x11 payload[3]) is one ride,
  measured with the scooter's odometer and battery %. The summary goes to a
  phone notification and a 0x53 message card ("12.4km Saved Rs23"). The
  money line assumes a 3.4 kWh pack, ₹8/kWh, petrol ₹101/L at 50 km/L.
- **Rain alert**: Open-Meteo's 15-minute forecast. If rain is due within the
  hour, the weather line reads "Rain soon 28⁰ C" and a message card plus a
  phone notification say "Rain in 30 min" (once an hour at most).
