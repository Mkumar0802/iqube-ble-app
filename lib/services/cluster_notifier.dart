import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../ble/frame_parser.dart';
import '../ble/gatt_constants.dart';
import '../ble/vehicle_service.dart';
import 'app_settings.dart';
import 'cluster_music.dart';
import 'cluster_navigation.dart';
import 'maps_navigation.dart';

/// Forwards phone notifications (calls, WhatsApp, SMS...) to the scooter's
/// cluster display.
///
/// Both are plain ASCII text frames (max 17 chars), checked on the cluster:
/// 0x43 + caller name = "Incoming call..." popup, 0x53 = "Text Message"
/// card. 0x63 is the music card, and 0x4C and the headed 0x53 "Test" frame
/// TVS Connect sends on connect showed nothing.
class ClusterNotifier extends ChangeNotifier {
  ClusterNotifier._();
  static final ClusterNotifier instance = ClusterNotifier._();

  static const _events = EventChannel('iqube/notifications');
  static const _methods = MethodChannel('iqube/notification_access');

  StreamSubscription? _sub;
  bool accessGranted = false;
  final List<String> sentLog = [];
  final Map<String, DateTime> _recent = {};

  /// The cluster hides the call popup after 2-5 s, so a ringing phone call
  /// is re-sent every 2 s until it is answered or ends (60 s at most).
  Timer? _ringing;

  static const _dialers = {
    'com.android.dialer',
    'com.google.android.dialer',
    'com.android.incallui',
    'com.android.server.telecom',
  };

  Future<void> init() async {
    await refreshAccess();
    _sub = _events.receiveBroadcastStream().listen(_onNotification,
        onError: (_) {});
  }

  Future<void> refreshAccess() async {
    try {
      accessGranted = await _methods.invokeMethod<bool>('isEnabled') ?? false;
    } catch (_) {
      accessGranted = false;
    }
    notifyListeners();
  }

  Future<void> openAccessSettings() =>
      _methods.invokeMethod('openSettings');

  void _onNotification(dynamic event) {
    if (event is! Map) return;
    final pkg = event['package'] as String? ?? '';
    if (pkg == 'media') {
      ClusterMusic.instance.onMedia(event);
      return;
    }
    if (MapsNavigation.packages.contains(pkg)) {
      ClusterNavigation.instance.onMapsNotification(event);
      return;
    }
    final s = AppSettings.instance;
    if (!s.clusterNotifications || event['category'] == 'removed') return;
    if (event['category'] == 'call_ended') {
      _ringing?.cancel();
      return;
    }
    final isCall = event['category'] == 'call';
    // Phone calls come from CallStateReceiver ('phone_state') as soon as
    // the phone rings. The dialer's own notification can arrive only after
    // the call ends, so it is skipped. Other call notifications (WhatsApp
    // calls) and switched-on apps are forwarded.
    final wanted = pkg == 'phone_state' ||
        (isCall && !_dialers.contains(pkg)) ||
        (!isCall && s.clusterApps.contains(pkg));
    debugPrint('IQNOTIF $pkg category=${event['category']} '
        '${wanted ? 'forwarding' : 'skipped'}');
    if (!wanted) return;
    final title = (event['title'] as String? ?? '').trim();
    final text = (event['text'] as String? ?? '').trim();
    if (title.isEmpty) return;

    // Messaging apps re-post the same notification often; send each once.
    final key = '$pkg|$title|$text';
    final now = DateTime.now();
    _recent.removeWhere((_, t) => now.difference(t) > const Duration(seconds: 30));
    if (_recent.containsKey(key)) return;
    _recent[key] = now;

    if (pkg == 'phone_state') {
      _ringFor(title);
    } else if (isCall) {
      sendCall(title);
    } else {
      sendMessage(text.isEmpty ? title : '$title: $text');
    }
  }

  void _ringFor(String caller) {
    _ringing?.cancel();
    sendCall(caller);
    final started = DateTime.now();
    _ringing = Timer.periodic(const Duration(seconds: 2), (t) {
      if (DateTime.now().difference(started) > const Duration(seconds: 60)) {
        t.cancel();
        return;
      }
      VehicleService.instance.send(FrameParser.textFrame(DataId.callerId, caller));
    });
  }

  Future<bool> sendCall(String caller) =>
      _send('Call: $caller', FrameParser.textFrame(DataId.callerId, caller));

  /// Plain ASCII text in a 0x53 frame (max 17 chars) brings up the
  /// cluster's "Text Message" card.
  Future<bool> sendMessage(String text) =>
      _send('Message: $text', FrameParser.textFrame(DataId.sms, text));

  Future<bool> _send(String label, List<int> frame) async {
    final ok = await VehicleService.instance.send(frame);
    final time = DateTime.now().toIso8601String().substring(11, 19);
    sentLog.insert(0, '$time  ${ok ? 'sent' : 'NOT sent (scooter offline)'}  $label');
    if (sentLog.length > 50) sentLog.removeLast();
    notifyListeners();
    return ok;
  }

  @override
  void dispose() {
    _ringing?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}
