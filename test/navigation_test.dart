import 'package:flutter_test/flutter_test.dart';
import 'package:iqube_ble_app/ble/frame_parser.dart';
import 'package:iqube_ble_app/services/maps_navigation.dart';

String hex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join(' ');

void main() {
  test('control frame matches TVS byteArrayForNavigation layout', () {
    // 300 m to a left turn, 12 min and 4.5 km left.
    final f = FrameParser.navigationControlFrame(
        metresToTurn: 300, minutesLeft: 12, metresLeft: 4500, maneuver: 0,
        longText: false);
    final plain = f.sublist(2, 19).map((b) => b ^ 0xeb).toList();
    expect(f[0], 0x5a);
    expect(f[1], 0x4e);
    expect(hex(plain),
        '01 2c 00 0c 00 11 94 00 01 00 00 00 00 00 00 00 00');
    expect(f[19], 0xff);
  });

  test('text frame is 5B 4F with the instruction', () {
    final f = FrameParser.navigationTextFrame('Anna Salai');
    expect(hex(f.sublist(0, 2)), '5b 4f');
    expect(String.fromCharCodes(f.sublist(2, 12).map((b) => b ^ 0xeb)),
        'Anna Salai');
  });

  test('parses Maps notification in either order', () {
    final a = MapsNavigation.parse(
        '200 m', 'Turn left onto Anna Salai', '12 min · 3.4 km · 10:45 am ETA')!;
    expect(a.metresToTurn, 200);
    expect(a.maneuver, 0); // left
    expect(a.clusterText, 'Anna Salai');
    expect(a.minutesLeft, 12);
    expect(a.metresLeft, 3400);

    final b = MapsNavigation.parse(
        'Turn right toward Guindy', '1.2 km', '1 hr 5 min · 45 km')!;
    expect(b.metresToTurn, 1200);
    expect(b.maneuver, 10); // right
    expect(b.minutesLeft, 65);
    expect(b.metresLeft, 45000);

    // First step, as captured from Maps on the phone.
    final c = MapsNavigation.parse(
        '', 'Head northwest', '14 min · 3.8 km · 1:41 PM ETA')!;
    expect(c.metresToTurn, 0);
    expect(c.maneuver, 57); // straight, as seen on the cluster
    expect(c.minutesLeft, 14);
    expect(c.metresLeft, 3800);

    expect(MapsNavigation.parse('Rerouting…', '', ''), isNull);
  });

  test('Mappls id -> cluster arrow', () {
    expect(MapsNavigation.clusterArrow(21), 57);
    expect(MapsNavigation.clusterArrow(41), 19);
    expect(MapsNavigation.clusterArrow(0), 0);
    expect(MapsNavigation.clusterArrow(66), 28);
  });

  test('instruction -> Mappls maneuver id', () {
    expect(MapsNavigation.maneuverFor('Make a U-turn'), 41);
    expect(MapsNavigation.maneuverFor('At the roundabout, take the 2nd exit'), 66);
    expect(MapsNavigation.maneuverFor('Slight right onto NH 48'), 5);
    expect(MapsNavigation.maneuverFor('Keep left at the fork'), 19);
    expect(MapsNavigation.maneuverFor('Sharp left'), 1);
    expect(MapsNavigation.maneuverFor('Destination will be on the right'), 10);
    expect(MapsNavigation.maneuverFor('Head north on Mount Road'), 21);
  });
}
