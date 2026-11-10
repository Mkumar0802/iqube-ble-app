import 'package:flutter_test/flutter_test.dart';
import 'package:iqube_ble_app/services/maps_navigation.dart';

void main() {
  test('trip from sub-text', () {
    final s = MapsNavigation.parse('400 m', 'Turn right onto Anna Salai',
        '14 min · 3.8 km · 9:39 AM ETA')!;
    expect(s.metresToTurn, 400);
    expect(s.minutesLeft, 14);
    expect(s.metresLeft, 3800);
  });

  test('trip in another field, big text repeats the step', () {
    final s = MapsNavigation.parse('400 m', 'Turn right',
        '400 m · Turn right onto Anna Salai\n1 hr 5 min · 42 km')!;
    expect(s.minutesLeft, 65);
    expect(s.metresLeft, 42000);
  });

  test('countdown time when no field has minutes', () {
    final s = MapsNavigation.parse('400 m', 'Turn right', '',
        arrival: DateTime.now().add(const Duration(minutes: 9, seconds: 30)))!;
    expect(s.minutesLeft, 10);
    expect(s.metresLeft, isNull);
  });
}
