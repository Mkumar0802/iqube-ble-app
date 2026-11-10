import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../ble/frame_parser.dart';
import '../ble/gatt_constants.dart';
import '../ble/vehicle_service.dart';
import 'app_settings.dart';

/// The playing song on the cluster's music card, and the handlebar buttons
/// on the phone.
///
/// Any app with a media session works (Spotify, YouTube Music, ...). The
/// song goes out as plain text in 0x63, which brings up the music card.
/// The buttons show up for ~0.3 s as a code in the 0x10 status frame
/// (payload[10], frame byte 12; bit 0x80 there is TVS's ignition-off flag).
/// Checked one button at a time on the scooter: right and centre both send
/// 01, left 02, volume up 03, volume down nothing. 05 showed up during the
/// first tests (maybe a long press). TVS Connect only uses 04, for its
/// voice assistant.
class ClusterMusic extends ChangeNotifier {
  ClusterMusic._();
  static final ClusterMusic instance = ClusterMusic._();

  static const _media = MethodChannel('iqube/media');

  static const _buttons = {
    1: 'next',
    2: 'previous',
    3: 'volumeUp',
    5: 'toggle',
    4: 'assistant',
  };

  String? title;
  String? artist;
  bool playing = false;
  String? lastButton;

  String? _sent;
  bool _wasConnected = false;
  int _button = 0;

  void init() {
    VehicleService.instance.frames.listen(_onFrame);
    VehicleService.instance.addListener(_onVehicle);
  }

  /// Called by ClusterNotifier with media session changes.
  void onMedia(Map event) {
    title = (event['title'] as String? ?? '').trim();
    artist = (event['text'] as String? ?? '').trim();
    playing = event['playing'] == true;
    notifyListeners();
    _sendSong();
  }

  String get songLine {
    final t = title ?? '';
    final a = artist ?? '';
    return a.isEmpty ? t : '$t - $a';
  }

  /// Sends the song once per track, and again after reconnecting.
  void _sendSong() {
    if (!AppSettings.instance.clusterMusic || !playing) return;
    final line = songLine;
    if (line.isEmpty || line == _sent) return;
    final v = VehicleService.instance;
    if (!v.isConnected) return;
    _sent = line;
    v.send(FrameParser.textFrame(DataId.message2, line));
  }

  void _onVehicle() {
    final connected = VehicleService.instance.isConnected;
    if (connected == _wasConnected) return;
    _wasConnected = connected;
    _sent = null;
    if (connected) _sendSong();
  }

  void _onFrame(ParsedFrame f) {
    if (!f.looksLikeTaggedFrame ||
        f.dataId != DataId.status10 ||
        f.payload.length < 11) {
      return;
    }
    final code = f.payload[10] & 0x7f;
    final pressed = code != 0 && _button == 0;
    _button = code;
    if (!pressed || !AppSettings.instance.clusterMusic) return;

    final action = _buttons[code];
    debugPrint('IQMUSIC button $code -> $action');
    lastButton = '${action ?? 'not used'} (code $code)';
    notifyListeners();
    if (action != null) _media.invokeMethod(action).catchError((_) {});
  }
}
