import 'dart:async';

import 'package:flutter/foundation.dart';

import '../ble/frame_parser.dart';
import '../ble/vehicle_service.dart';
import 'app_settings.dart';
import 'maps_navigation.dart';

/// Shows Google Maps turn-by-turn directions on the cluster, in the same
/// frames TVS Connect uses for its own navigation. No TVS account or
/// subscription is involved: the directions come from Maps' notification.
class ClusterNavigation extends ChangeNotifier {
  ClusterNavigation._();
  static final ClusterNavigation instance = ClusterNavigation._();

  NavStep? step;

  /// The last Maps notification, shown in Settings for checking.
  String? lastMaps;
  DateTime? _seenAt;
  Timer? _resend;
  bool _sending = false;

  /// Called by ClusterNotifier for Google Maps notifications.
  void onMapsNotification(Map event) {
    if (event['category'] == 'removed') {
      _stop();
      return;
    }
    final title = event['title'] as String? ?? '';
    final text = event['text'] as String? ?? '';
    final sub = event['subText'] as String? ?? '';
    // Other text fields (big text, info text, ...) that may hold the trip.
    final extras = (event['extras'] as Map? ?? const {})
        .map((k, v) => MapEntry('$k', '$v'))
      ..removeWhere((k, v) =>
          v.trim().isEmpty ||
          k == 'android.title' ||
          k == 'android.text' ||
          k == 'android.subText');
    final when = event['when'] as int? ?? 0;
    final countDown = event['countDown'] as bool? ?? false;
    debugPrint('IQNAV title="$title" text="$text" sub="$sub" '
        'extras=$extras when=$when countDown=$countDown');
    lastMaps = [title, text, sub, ...extras.values]
        .where((x) => x.isNotEmpty)
        .join(' | ');
    notifyListeners();
    if (!AppSettings.instance.clusterNavigation) return;
    final next = MapsNavigation.parse(title, text,
        [sub, ...extras.values].where((x) => x.isNotEmpty).join('\n'),
        arrival: countDown && when > 0
            ? DateTime.fromMillisecondsSinceEpoch(when)
            : null);
    if (next == null) return;
    _seenAt = DateTime.now();
    final changed = next != step;
    step = next;
    if (changed) {
      debugPrint('IQNAV step $next');
      notifyListeners();
      unawaited(_send());
    }
    // The cluster drops directions it stops hearing about, so the step is
    // repeated until Maps goes quiet for a minute.
    _resend ??= Timer.periodic(const Duration(seconds: 3), (_) {
      if (DateTime.now().difference(_seenAt!) > const Duration(minutes: 1)) {
        _stop();
      } else {
        unawaited(_send());
      }
    });
  }

  /// Arrow check: shows each candidate arrow code for 4 s with the
  /// distance set to the code ("21 m" = code 21), to match codes to the
  /// cluster's arrows without driving.
  static const testArrows = [57, 0, 10, 2, 12, 1, 11, 19, 22, 28, 64, 49, 8, 18, 7, 17];

  void sendTest() {
    for (var i = 0; i < testArrows.length * 2; i++) {
      Timer(Duration(seconds: i * 2), () {
        final id = testArrows[i ~/ 2];
        step = NavStep(
          metresToTurn: id,
          instruction: 'Arrow $id',
          maneuver: id,
          minutesLeft: 5,
          metresLeft: 1200,
        );
        notifyListeners();
        unawaited(_send());
      });
    }
  }

  Future<void> _send() async {
    final s = step;
    if (s == null || _sending) return;
    _sending = true;
    final v = VehicleService.instance;
    try {
      await v.send(FrameParser.navigationTextFrame(s.clusterText));
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await v.send(FrameParser.navigationControlFrame(
        metresToTurn: s.metresToTurn,
        minutesLeft: s.minutesLeft ?? 0,
        metresLeft: s.metresLeft ?? s.metresToTurn,
        maneuver: s.maneuver,
        longText: s.clusterText.length > 17,
      ));
    } finally {
      _sending = false;
    }
  }

  void _stop() {
    _resend?.cancel();
    _resend = null;
    if (step == null) return;
    step = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _resend?.cancel();
    super.dispose();
  }
}
