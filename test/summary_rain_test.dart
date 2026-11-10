import 'package:flutter_test/flutter_test.dart';
import 'package:iqube_ble_app/services/cluster_info.dart';
import 'package:iqube_ble_app/services/ride_summary.dart';

void main() {
  test('ride summary text and 17-char cluster line', () {
    final s = RideSummary.summarize(km: 12.4, minutes: 32, batteryUsed: 6);
    expect(s.text, contains('12.4 km in 32 min'));
    expect(s.text, contains('6% battery (2.1 km per %)'));
    // Petrol 12.4/50*101 = 25.0; electric 0.06*3.4*8 = 1.6 -> saved 23.
    expect(s.text, contains('saved ₹23'));
    expect(s.cluster, '12.4km Saved Rs23');
    expect(s.cluster.length, lessThanOrEqualTo(17));
  });

  test('rain soon from 15-minute slots', () {
    expect(ClusterInfo.rainSoon(rainingNow: false, next15min: [0, 0, 0.5, 1]), 30);
    expect(ClusterInfo.rainSoon(rainingNow: false, next15min: [0, 0.1, 0, 0]), isNull);
    expect(ClusterInfo.rainSoon(rainingNow: true, next15min: [1, 1, 1, 1]), isNull);
  });
}
