import 'package:flutter_test/flutter_test.dart';
import 'package:iqube_ble_app/services/permission_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PermissionService singleton exists and initial states are valid', () {
    final ps = PermissionService.instance;
    expect(ps, isNotNull);
    expect(ps.isBluetoothGranted, isFalse);
    expect(ps.isLocationGranted, isFalse);
  });
}

