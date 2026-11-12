import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqube_ble_app/theme/app_theme.dart';
import 'package:iqube_ble_app/ui/widgets/battery_orb.dart';

Widget _app(Widget child, {bool still = false}) => MaterialApp(
      theme: buildAppTheme(Brightness.dark),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: still),
        child: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  testWidgets('orb counts up to the level and reads it out', (tester) async {
    await tester.pumpWidget(
        _app(const BatteryOrb(percent: 64, charging: true, caption: 'Charging')));
    // The wave loops for ever, so step past the count-up instead of settling.
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('64'), findsOneWidget);
    expect(find.text('Charging'), findsOneWidget);
    expect(find.bySemanticsLabel('Battery 64 percent, charging, Charging'),
        findsOneWidget);
  });

  testWidgets('with animations off the level shows at once and nothing loops',
      (tester) async {
    await tester.pumpWidget(
        _app(const BatteryOrb(percent: 20, charging: true), still: true));
    expect(find.text('20'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });

  test('battery colour follows the level', () {
    const c = AppColors.dark;
    expect(c.level(10), c.danger);
    expect(c.level(30), c.warning);
    expect(c.level(80), c.energy);
  });
}
