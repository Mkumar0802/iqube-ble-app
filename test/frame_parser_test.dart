import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:iqube_ble_app/ble/frame_parser.dart';

String hex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join(' ');

void main() {
  test('hello frame matches TVS Connect capture', () {
    expect(hex(FrameParser.helloFrame()),
        '5a 53 ef eb 94 eb eb fb ee bf 8e 98 9f eb eb eb eb eb f1 ff');
  });

  test('time heartbeat matches TVS Connect capture at 12:43:11', () {
    expect(hex(FrameParser.timeHeartbeatFrame(DateTime(2026, 10, 25, 12, 43, 11))),
        '5b 4a a8 93 eb e9 e7 c0 e0 ea fb ef eb eb eb eb eb eb eb ff');
  });

  test('time heartbeat matches TVS Connect capture at 09:45:45 AM', () {
    final f = FrameParser.timeHeartbeatFrame(DateTime(2026, 11, 8, 9, 45, 45));
    expect(f.sublist(2, 12).map((x) => x ^ 0xEB).toList(),
        [0x30, 0x78, 0x00, 0x02, 0x09, 0x2d, 0x2d, 0x00, 0x00, 0x05]);
  });

  test('time heartbeat sends PM hours on a 12-hour clock', () {
    final f = FrameParser.timeHeartbeatFrame(DateTime(2026, 11, 8, 21, 5, 0));
    expect(f.sublist(2, 12).map((x) => x ^ 0xEB).toList(),
        [0x43, 0x78, 0x00, 0x02, 9, 5, 0, 0x01, 0x10, 0x04]);
  });

  test('weather frame matches TVS Connect capture "Clouds 28⁰ C"', () {
    final f = FrameParser.bytesFrame(0x5d, utf8.encode('Clouds 28⁰ C'));
    expect(hex(f.sublist(2, 16).map((x) => x ^ 0xEB).toList()),
        '43 6c 6f 75 64 73 20 32 38 e2 81 b0 20 43');
    expect(f.length, 20);
  });

  test('DTE and odometer match the cluster (43%, 46 km, 10102.8 km)', () {
    final battery = FrameParser.parse([0x5a, 0x13, 0x2b, 0x01, 0xcc, 0x06,
      ...List.filled(13, 0), 0xff]);
    final status = FrameParser.parse([0x5a, 0x10, 0x00, 0x01, 0x8a, 0xa4, 0x0f,
      ...List.filled(12, 0), 0xff]);
    expect(FrameParser.batteryPercent(battery), 43);
    expect(FrameParser.dteKm(battery), 46.0);
    expect(FrameParser.odometerKm(status), 10102.8);
    expect(FrameParser.dteKm(status), isNull);
  });

  test('battery % from 0x13 and 0x11 frames', () {
    final f13 = FrameParser.parse([0x5a, 0x13, 0x64, 0x04, 0x1a, 0x06,
      ...List.filled(13, 0), 0xff]);
    final f11 = FrameParser.parse([0x5a, 0x11, 0x00, 0x00, 0x02, 0x01, 0x62,
      ...List.filled(12, 0), 0xff]);
    expect(FrameParser.batteryPercent(f13), 100);
    expect(FrameParser.batteryPercent(f11), 98);
  });

  test('message frame reproduces the captured "Test" frame', () {
    expect(FrameParser.messageFrame('Test'), FrameParser.helloFrame());
    expect(hex(FrameParser.messageFrame('Test')),
        '5a 53 ef eb 94 eb eb fb ee bf 8e 98 9f eb eb eb eb eb f1 ff');
  });

  test('text frames are 20 bytes, ASCII-only and truncated', () {
    final f = FrameParser.textFrame(0x43, 'Amma 😀 calling you now');
    expect(f.length, 20);
    final text = String.fromCharCodes(f.sublist(2, 19).map((b) => b ^ 0xeb));
    expect(text, 'Amma ? calling yo');
  });
}
