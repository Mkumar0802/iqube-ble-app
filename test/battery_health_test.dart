import 'package:flutter_test/flutter_test.dart';
import 'package:iqube_ble_app/services/battery_health.dart';

void main() {
  test('months add up days and need 5% for a range', () {
    final months = BatteryHealth.monthsFrom({
      '2026-10-30': {'km': 20.0, 'used': 4, 'charged': 50, 'dteSum': 210.0, 'dteCount': 2},
      '2026-11-01': {'km': 10.6, 'used': 10, 'charged': 0},
      '2026-11-08': {'km': 0, 'used': 0, 'charged': 30, 'dteSum': 104.0, 'dteCount': 1},
    });
    expect(months.map((m) => m.month), ['2026-10', '2026-11']);
    expect(months[0].kmPerPercent, isNull); // only 4% used
    expect(months[0].clusterRangeKm, 105);
    expect(months[0].cycles, 0.5);
    expect(months[1].fullRangeKm, closeTo(106, 0.01));
    expect(months[1].charged, 30);
  });
}
