import 'dart:typed_data';

import 'gatt_constants.dart';

/// Result of attempting to parse one notification payload.
class ParsedFrame {
  final bool looksLikeTaggedFrame;
  final int? startByte;
  final int? dataId;
  final List<int> payload;
  final String hexDump;
  final String asciiPreview;

  ParsedFrame({
    required this.looksLikeTaggedFrame,
    required this.startByte,
    required this.dataId,
    required this.payload,
    required this.hexDump,
    required this.asciiPreview,
  });

  @override
  String toString() {
    if (looksLikeTaggedFrame) {
      return 'start=0x${startByte!.toRadixString(16)} '
          'dataId=0x${dataId!.toRadixString(16)} '
          'payload=$hexDump';
    }
    return 'raw=$hexDump ascii="$asciiPreview"';
  }
}

/// Best-effort decoder for the notification bytes your vehicle sends.
///
/// This does NOT know your vehicle's exact byte layout — nobody can,
/// without your own capture to verify against. What it does do:
///  - Shows you the raw hex + ASCII every single time, so you can eyeball
///    patterns (e.g. "does byte[2] change 0->100 while I charge? that's
///    probably battery %").
///  - Flags whether the frame matches the official app's
///    [startByte]..[dataId]..payload..[postfix] shape, and if so, prints
///    which DataId it matched against the recovered map.
///  - Flags whether it looks like a legacy single-ASCII-letter-prefixed
///    frame instead.
class FrameParser {
  static ParsedFrame parse(List<int> bytes) {
    final hex =
        bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    final ascii = String.fromCharCodes(
      bytes.map((b) => (b >= 32 && b <= 126) ? b : 0x2E), // '.' for non-printable
    );

    final looksTagged = bytes.isNotEmpty &&
        (bytes.first == DataId.startByte || bytes.first == DataId.startByteN360c) &&
        bytes.length >= 2;

    if (looksTagged) {
      return ParsedFrame(
        looksLikeTaggedFrame: true,
        startByte: bytes[0],
        dataId: bytes[1],
        payload: bytes.length > 2 ? bytes.sublist(2) : const [],
        hexDump: hex,
        asciiPreview: ascii,
      );
    }

    return ParsedFrame(
      looksLikeTaggedFrame: false,
      startByte: null,
      dataId: null,
      payload: bytes,
      hexDump: hex,
      asciiPreview: ascii,
    );
  }

  /// Human-readable label for a known DataId byte, if recognised.
  static String labelForDataId(int id) {
    switch (id) {
      case DataId.name:
        return 'NAME';
      case DataId.sms:
        return 'SMS';
      case DataId.callerId:
        return 'CALLER_ID';
      case DataId.message1:
        return 'MESSAGE_1 (e.g. app notification banner)';
      case DataId.message2:
        return 'MESSAGE_2';
      case DataId.trackTitle:
        return 'TRACK_TITLE';
      case DataId.trackArtist:
        return 'TRACK_ARTIST';
      case DataId.trackAlbum:
        return 'TRACK_ALBUM';
      case DataId.trackPlaybackState:
        return 'TRACK_PLAYBACK_STATE';
      case DataId.currentLocation:
        return 'CURRENT_LOCATION';
      case DataId.climateOrWeather:
        return 'CLIMATE_OR_WEATHER';
      case DataId.navigationControl:
        return 'NAVIGATION_CONTROL';
      case DataId.navigationData1:
        return 'NAVIGATION_DATA_1';
      case DataId.navigationData2:
        return 'NAVIGATION_DATA_2';
      case DataId.musicPlayback:
        return 'MUSIC_PLAYBACK';
      case DataId.accessoryControl:
        return 'ACCESSORY_CONTROL';
      case DataId.disconnect:
        return 'DISCONNECT';
      case DataId.status10:
        return 'STATUS_10';
      case DataId.status11:
        return 'STATUS_11';
      case DataId.battery:
        return 'BATTERY';
      case DataId.helloAck:
        return 'HELLO_ACK';
      case DataId.status7d:
        return 'STATUS_7D';
      default:
        return 'UNKNOWN (0x${id.toRadixString(16)}) — log this and compare '
            'against what the dashboard shows at the same moment';
    }
  }

  /// Battery % from a scooter frame, or null if this frame doesn't carry it.
  static int? batteryPercent(ParsedFrame f) {
    if (!f.looksLikeTaggedFrame) return null;
    if (f.dataId == DataId.battery && f.payload.isNotEmpty) return f.payload[0];
    if (f.dataId == DataId.status11 && f.payload.length > 4) return f.payload[4];
    return null;
  }

  /// Distance to empty in km, as the cluster shows it ("DTE").
  /// Battery frame payload[1..2], big-endian tenths of a km
  /// (2b 01 cc = 43%, 46.0 km on the cluster).
  static double? dteKm(ParsedFrame f) {
    if (!f.looksLikeTaggedFrame || f.dataId != DataId.battery) return null;
    if (f.payload.length < 3) return null;
    return ((f.payload[1] << 8) | f.payload[2]) / 10;
  }

  /// Odometer in km. Status 0x10 payload[0..3], big-endian tenths of a km
  /// (00 01 8a a4 = 10102.8 km on the cluster).
  static double? odometerKm(ParsedFrame f) {
    if (!f.looksLikeTaggedFrame || f.dataId != DataId.status10) return null;
    if (f.payload.length < 4) return null;
    final p = f.payload;
    return ((p[0] << 24) | (p[1] << 16) | (p[2] << 8) | p[3]) / 10;
  }

  /// Ignition from 0x11 payload[3] (01 on, 00 off), or null for other
  /// frames.
  static bool? ignitionOn(ParsedFrame f) {
    if (!f.looksLikeTaggedFrame || f.dataId != DataId.status11) return null;
    if (f.payload.length < 4) return null;
    return f.payload[3] == 1;
  }

  /// Builds a 20-byte phone -> scooter frame the way TVS Connect does:
  /// [start, dataId, 17 payload bytes XORed with 0xEB, 0xFF].
  static Uint8List buildPhoneFrame(int dataId, List<int> payload,
      {int start = DataId.startByteN360c}) {
    final body = List<int>.filled(17, 0);
    for (var i = 0; i < payload.length && i < 17; i++) {
      body[i] = payload[i];
    }
    return Uint8List.fromList([
      start,
      dataId,
      ...body.map((b) => b ^ DataId.phonePayloadXor),
      DataId.postfix,
    ]);
  }

  /// The first frame TVS Connect sends after connecting (DataId 0x53,
  /// payload "...Test"); the scooter answers with [DataId.helloAck].
  static Uint8List helloFrame() => messageFrame('Test');

  /// Raw bytes (cut to 17) in a phone frame, for text that isn't plain
  /// ASCII, like the UTF-8 weather line.
  static Uint8List bytesFrame(int dataId, List<int> bytes) =>
      buildPhoneFrame(dataId, bytes.length > 17 ? bytes.sublist(0, 17) : bytes);

  /// Plain ASCII text frame, like the name (0x52) and phone number (0x81)
  /// frames TVS Connect sends. Text is cut to 17 characters.
  static Uint8List textFrame(int dataId, String text) =>
      buildPhoneFrame(dataId, _ascii(text, 17));

  /// The 0x53 "Test" frame TVS Connect sends on connect: a 7-byte header,
  /// the text, then 0x1A. The cluster shows nothing for it; plain text in a
  /// 0x53 frame (see [textFrame]) is what brings up the message card.
  static Uint8List messageFrame(String text) {
    final body = List<int>.filled(16, 0)
      ..setRange(0, 7, const [0x04, 0x00, 0x7f, 0x00, 0x00, 0x10, 0x05]);
    final chars = _ascii(text, 9);
    body.setRange(7, 7 + chars.length, chars);
    return buildPhoneFrame(DataId.sms, [...body, 0x1a],
        start: DataId.startByte);
  }

  /// The cluster can't show emoji or non-Latin text; replace with '?'.
  /// Turn-by-turn numbers and arrow, as TVS Connect's
  /// BleNavigationSendData.byteArrayForNavigation builds them for the
  /// iQube: 5A 4E, metres to the turn (2), minutes left (2), metres left
  /// (3), Mappls maneuver id, 1 or 2 (instruction fits in 17 chars or
  /// not), then zeros.
  static Uint8List navigationControlFrame({
    required int metresToTurn,
    required int minutesLeft,
    required int metresLeft,
    required int maneuver,
    required bool longText,
  }) {
    final d = metresToTurn.clamp(0, 0xFFFF);
    final t = minutesLeft.clamp(0, 0xFFFF);
    final r = metresLeft.clamp(0, 0xFFFFFF);
    return buildPhoneFrame(
        DataId.navigationControl,
        [d >> 8, d & 0xff, t >> 8, t & 0xff, r >> 16, (r >> 8) & 0xff, r & 0xff,
            maneuver, longText ? 2 : 1],
        start: DataId.startByte);
  }

  /// The instruction line shown under the arrow (5B 4F + 17 chars). TVS
  /// sends it 400 ms before [navigationControlFrame].
  static Uint8List navigationTextFrame(String text) =>
      textFrame(DataId.navigationData1, text);

  static List<int> _ascii(String text, int max) {
    final out = <int>[];
    for (final r in text.runes) {
      if (out.length == max) break;
      out.add(r >= 32 && r < 127 ? r : 0x3f);
    }
    return out;
  }

  /// Time heartbeat TVS Connect sends every 2 s. Only HH MM SS are known;
  /// the other bytes are copied as captured.
  static Uint8List timeHeartbeatFrame(DateTime now) {
    // Byte layout copied from TVS Connect captures, which differ between
    // morning (09:45 AM: 30 78 00 02 09 MM SS 00 00 05) and afternoon
    // (12:19 PM: 43 78 00 02 0c MM SS 01 10 05). Byte 7 looks like the PM
    // flag. Hours past 12 are sent on a 12-hour clock (not yet seen in a
    // capture).
    final pm = now.hour >= 12;
    final hour12 = now.hour % 12 == 0 ? 12 : now.hour % 12;
    return buildPhoneFrame(
      DataId.timeHeartbeat,
      pm
          ? [0x43, 0x78, 0x00, 0x02, hour12, now.minute, now.second, 0x01, 0x10, 0x04]
          : [0x30, 0x78, 0x00, 0x02, hour12, now.minute, now.second, 0x00, 0x00, 0x05],
    );
  }

  static Uint8List toUint8List(List<int> bytes) => Uint8List.fromList(bytes);
}
