import 'package:flutter_test/flutter_test.dart';
import 'package:iqube_ble_app/main.dart';
import 'package:iqube_ble_app/services/app_settings.dart';
import 'package:iqube_ble_app/ui/splash_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.instance.load();
  });

  testWidgets('Clicking home and settings tabs does not throw duplicate keys',
      (tester) async {
    await tester.pumpWidget(const IQubeApp(showSplash: false));
    await tester.pump(const Duration(milliseconds: 350));

    // Tap on Settings tab
    final settingsTab = find.text('Settings');
    expect(settingsTab, findsOneWidget);
    await tester.tap(settingsTab);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    // Tap on Home tab
    final homeTab = find.text('Home');
    expect(homeTab, findsOneWidget);
    await tester.tap(homeTab);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    // Tap on Settings tab again to ensure rapid tab toggling is completely clean
    await tester.tap(settingsTab);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    // Tap back to Home
    await tester.tap(homeTab);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  });

  testWidgets('SplashScreen displays Save Trees and EV drive theme',
      (tester) async {
    var completed = false;
    await tester.pumpWidget(IQubeApp(
      showSplash: true,
      home: SplashScreen(
        durationSeconds: 5,
        onComplete: () => completed = true,
      ),
    ));

    // Verify eco-friendly text
    expect(find.text('🌳 SAVE TREES'), findsOneWidget);
    expect(find.text('Ride 100% Electric'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);

    // Tap skip
    await tester.tap(find.text('Skip'));
    await tester.pump();
    expect(completed, isTrue);
  });
}
