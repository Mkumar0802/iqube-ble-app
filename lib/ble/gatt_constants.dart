// gatt_constants.dart
//
// IMPORTANT — READ THIS FIRST
// ----------------------------------------------------------------------
// TVS does NOT hardcode the BLE Service / Characteristic UUIDs inside the
// official "TVS Connect" APK. They are fetched from TVS's backend at
// runtime (after login + pairing your specific vehicle) and cached in
// local app preferences, keyed per bike/EV model (N109, N251, N360, U368,
// U399, U400, U408, U507, RTR_160_IOT, iQube/EV models, etc.).
//
// Because of that, there is no single "correct" UUID to paste in below —
// it depends on your exact vehicle's BLE module firmware. You have two
// ways to fill these in:
//
//   1. Capture an Android Bluetooth HCI snoop log while the official TVS
//      Connect app connects to YOUR OWN vehicle, open it in Wireshark,
//      and copy the real Service/Characteristic UUIDs you see.
//
//   2. Run this app's BleExplorerScreen against your own vehicle first —
//      it has no hardcoded UUIDs at all, it just connects and lists every
//      service + characteristic (and their properties: read/write/notify)
//      that your vehicle's BLE module advertises. Often there is only one
//      "custom" 128-bit service with a notify characteristic and a write
//      characteristic — that pair is almost certainly your data channel.
//
// Once you know the real UUIDs, paste them below and switch MainScreen to
// use TelemetryScreen instead of BleExplorerScreen.
// ----------------------------------------------------------------------

class GattConstants {
  // Discovered with BleExplorerScreen on TVSiQUBEEKD9484. The service UUID
  // is ASCII for "TVSMVGSASBENTORQ". The two characteristics use the
  // standard Bluetooth base UUID, so flutter_blue_plus prints them in
  // short 16-bit form — compare against `uuid.str`, which does the same.
  static const String serviceUuid = '5456534d-5647-5341-5342-454e544f5251';
  static const String notifyCharacteristicUuid = '5354';
  static const String writeCharacteristicUuid = '5352';

  // Standard BLE UUID, same on every device — NOT secret, not TVS-specific.
  // This is the Client Characteristic Configuration Descriptor, used to
  // turn notifications on/off on a characteristic.
  static const String cccdUuid = '00002902-0000-1000-8000-00805f9b34fb';
}

/// Single-byte "DATA_ID" tags used by the official app's framing protocol,
/// recovered from decompiling the public TVS Connect APK
/// (com.tvsm.connect.bluetooth.bluetoothlegatt.SampleGattAttributes).
///
/// These describe how a payload byte array is *tagged* once you already
/// receive it over the notify characteristic — they are plain app-level
/// framing constants (not secrets, not UUIDs), so they're safe to reuse.
/// Exact field availability/offsets can differ for EV (iQube) vs ICE bike
/// clusters — treat this as a starting map and verify against bytes you
/// actually capture from your own vehicle.
class DataId {
  static const int name = 0x52; // 82
  static const int sms = 0x53; // 83 - "Text Message / N message" card
  static const int callerId = 0x43; // 67 - shows "Incoming call..." on the iQube
  static const int message1 = 0x4C; // 76 (e.g. WhatsApp-style banner)
  static const int message2 = 0x63; // 99 - actually the iQube music card
  static const int trackTitle = 0x62; // 98
  static const int trackArtist = 0x65; // 101
  static const int trackAlbum = 0x61; // 97
  static const int trackPlaybackState = 0x60; // 96
  static const int currentLocation = 0x5C; // 92
  static const int climateOrWeather = 0x5D; // 93
  static const int navigationControl = 0x4E; // 78
  static const int navigationData1 = 0x4F; // 79
  static const int navigationData2 = 0x50; // 80
  static const int musicPlayback = 0x6B; // 107 - not sent by the iQube
  static const int vehicleControl = -0x0F; // 0xF1 as signed byte
  static const int accessoryControl = 0x57; // 87
  static const int disconnect = 0x12; // 18

  // Seen in an HCI snoop capture of TVS Connect talking to an iQube.
  // Scooter -> phone (plain bytes, not obfuscated):
  static const int status10 = 0x10; // ~3/s; constant while parked
  static const int status11 = 0x11; // payload[4] = battery % (same as 0x13)
  static const int battery = 0x13; // payload[0] = battery %
  static const int helloAck = 0x54; // echo of the 0x53 hello frame
  static const int status7d = 0x7D;
  // Phone -> scooter (payload XORed with [phonePayloadXor]):
  static const int timeHeartbeat = 0x4A; // sent every 2 s, carries HH MM SS
  static const int phoneSettings = 0x80;
  static const int phoneNumber = 0x81;

  /// Payload bytes the phone sends are XORed with this key (bytes 2..18).
  static const int phonePayloadXor = 0xEB;

  // Frame delimiters seen in the official app (BluetoothUtil / SampleGattAttributes).
  static const int startByte = 0x5A; // 90, most models
  static const int startByteN360c = 0x5B; // 91, N360C cluster variant
  static const int postfix = 0xFF; // frame terminator byte
}

/// Older ASCII single-letter prefixes used by the legacy SPP/serial
/// protocol (N109/U347/N251-era clusters). Included for reference — your
/// iQube EV most likely uses the newer binary DATA_ID framing above
/// instead, but if your captured bytes look like plain ASCII starting
/// with a single letter, check this map.
class LegacyAsciiPrefix {
  static const String speed = 'A';
  static const String rpm = 'R';
  static const String odometer = 'O';
  static const String averageSpeed = 'Z';
  static const String fuelLevel = 'F';
  static const String locationTag = 'B';
  static const String leanAngle = 'L';
  static const String gear = 'P';
}
