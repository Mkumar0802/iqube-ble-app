/// One turn-by-turn step read from Google Maps' navigation notification.
class NavStep {
  const NavStep({
    required this.metresToTurn,
    required this.instruction,
    required this.maneuver,
    this.minutesLeft,
    this.metresLeft,
  });

  final int metresToTurn;
  final String instruction;

  /// The cluster's arrow code (see [MapsNavigation.clusterArrow]).
  final int maneuver;
  final int? minutesLeft;
  final int? metresLeft;

  /// What fits under the arrow: the road name when there is one ("Turn left
  /// onto Anna Salai" -> "Anna Salai"), since the arrow shows the turn.
  String get clusterText {
    for (final w in const ['onto', 'towards', 'toward', 'on']) {
      final i = instruction.toLowerCase().indexOf(' $w ');
      if (i >= 0) return instruction.substring(i + w.length + 2).trim();
    }
    return instruction;
  }

  @override
  bool operator ==(Object other) =>
      other is NavStep &&
      other.metresToTurn == metresToTurn &&
      other.instruction == instruction &&
      other.maneuver == maneuver &&
      other.minutesLeft == minutesLeft &&
      other.metresLeft == metresLeft;

  @override
  int get hashCode =>
      Object.hash(metresToTurn, instruction, maneuver, minutesLeft, metresLeft);

  @override
  String toString() => '$metresToTurn m, "$instruction" (arrow $maneuver), '
      '${minutesLeft ?? '?'} min, ${metresLeft ?? '?'} m left';
}

/// Reads Google Maps' turn-by-turn notification. Maps puts the distance to
/// the next turn in one of title/text ("200 m") and the instruction in the
/// other ("Turn left onto Anna Salai"); the first step has only text
/// ("Head northwest") and an empty title. The sub-text holds the trip
/// ("14 min · 3.8 km · 1:41 PM ETA").
class MapsNavigation {
  MapsNavigation._();

  static const packages = {
    'com.google.android.apps.maps',
    'com.google.android.apps.navlite', // Maps Go
  };

  static final _distance =
      RegExp(r'(\d+(?:[.,]\d+)?)\s*(km|m|mi|ft)\b', caseSensitive: false);

  /// [trip] is the sub-text plus any other text fields, one per line; the
  /// trip is taken from the line holding the minutes. [arrival] is the
  /// notification's countdown time, used when no line has minutes.
  static NavStep? parse(String title, String text, String trip,
      {DateTime? arrival}) {
    int? metres;
    final words = <String>[];
    for (final part in [title.trim(), text.trim()]) {
      if (part.isEmpty) continue;
      final d = metres == null ? _leadingDistance(part) : null;
      if (d == null) {
        words.add(part);
        continue;
      }
      // "200 m" alone, or "200 m · Turn left" in a single field.
      metres = _metres(d);
      final rest =
          part.substring(d.end).replaceFirst(RegExp(r'^[\s·•,-]+'), '');
      if (rest.isNotEmpty) words.add(rest);
    }
    final instruction = words.join(' ');
    if (instruction.isEmpty ||
        RegExp(r'rerouting|gps signal|searching', caseSensitive: false)
            .hasMatch(instruction)) {
      return null;
    }

    final lines = trip.split('\n');
    final tripLine = lines.firstWhere((l) => _minutes(l) != null,
        orElse: () => lines.firstWhere((l) => _eta(l) != null,
            orElse: () => ''));
    final left = _distance.firstMatch(tripLine);
    return NavStep(
      // The first step ("Head northwest") comes without a distance.
      metresToTurn: metres ?? 0,
      instruction: instruction,
      maneuver: clusterArrow(maneuverFor(instruction)),
      minutesLeft: _minutes(tripLine) ??
          _minutesUntil(arrival) ??
          _minutesUntil(_eta(tripLine)),
      metresLeft: left == null ? null : _metres(left),
    );
  }

  static int? _minutesUntil(DateTime? t) {
    if (t == null) return null;
    final m = t.difference(DateTime.now()).inSeconds / 60;
    return m >= 0 && m < 24 * 60 ? m.ceil() : null;
  }

  /// "9:39 AM ETA" / "ETA 21:39" -> that time today (or tomorrow).
  static DateTime? _eta(String s) {
    final m = RegExp(r'(\d{1,2}):(\d{2})\s*([ap]\.?m\.?)?', caseSensitive: false)
        .firstMatch(s);
    if (m == null || !s.toLowerCase().contains('eta')) return null;
    var h = int.parse(m.group(1)!);
    final pm = m.group(3)?.toLowerCase().startsWith('p');
    if (pm != null) h = h % 12 + (pm ? 12 : 0);
    final now = DateTime.now();
    var t = DateTime(now.year, now.month, now.day, h, int.parse(m.group(2)!));
    if (t.isBefore(now.subtract(const Duration(minutes: 5)))) {
      t = t.add(const Duration(days: 1));
    }
    return t;
  }

  static RegExpMatch? _leadingDistance(String s) {
    final m = _distance.firstMatch(s);
    return m != null && s.substring(0, m.start).trim().isEmpty ? m : null;
  }

  static int _metres(RegExpMatch m) {
    final n = double.parse(m.group(1)!.replaceAll(',', '.'));
    return switch (m.group(2)!.toLowerCase()) {
      'km' => n * 1000,
      'mi' => n * 1609.34,
      'ft' => n * 0.3048,
      _ => n,
    }
        .round();
  }

  static int? _minutes(String s) {
    final h = RegExp(r'(\d+)\s*(?:hrs?|hours?|h)\b', caseSensitive: false)
        .firstMatch(s);
    final m = RegExp(r'(\d+)\s*min', caseSensitive: false).firstMatch(s);
    if (h == null && m == null) return null;
    return int.parse(h?.group(1) ?? '0') * 60 + int.parse(m?.group(1) ?? '0');
  }

  /// Mappls maneuver id -> the iQube cluster's arrow code, from TVS
  /// Connect's getPictogramForU725 table. Checked on the cluster: 57
  /// straight, 19 U-turn, 2 slight left, 0 left, 27-33 roundabout exits.
  static int clusterArrow(int mappls) => switch (mappls) {
        1 => 1,
        2 || 15 || 19 => 2,
        3 || 14 => 10,
        4 => 11,
        5 || 16 || 20 => 12,
        6 => 9,
        7 || 21 || 44 || 50 => 57,
        8 || 9 || 10 => 22,
        23 => 62,
        25 => 63,
        26 || 27 || 28 => 8,
        29 || 30 || 31 => 18,
        32 || 33 => 49,
        35 => 14,
        36 => 23,
        41 => 19,
        42 || 45 || 48 || 76 || 77 => 7,
        43 || 46 || 47 || 78 || 79 => 17,
        65 => 27,
        66 => 28,
        67 => 29,
        68 => 48,
        69 => 31,
        70 => 32,
        71 => 33,
        72 => 64,
        _ => 0,
      };

  /// Instruction text -> Mappls maneuver id (left-hand traffic), from the
  /// mappls-directions short instruction table in TVS Connect.
  static int maneuverFor(String instruction) {
    final s = instruction.toLowerCase();
    bool has(String w) => s.contains(w);
    final left = has('left');
    final right = has('right');

    if (has('u-turn') || has('u turn') || has('make a u')) return 41;
    if (has('roundabout') || has('rotary')) {
      final exit = RegExp(r'(\d+)(?:st|nd|rd|th)\s+exit').firstMatch(s);
      if (exit != null) return 64 + int.parse(exit.group(1)!).clamp(1, 7);
      return 72;
    }
    if (has('destination') || has('arrive') || has('arrived')) {
      return left ? 9 : (right ? 10 : 8);
    }
    if (has('ferry')) return 36;
    if (has('merge')) return left ? 26 : (right ? 29 : 33);
    if (has('ramp') || has('exit')) return left ? 48 : (right ? 43 : 44);
    if (has('keep') || has('fork')) return left ? 19 : (right ? 20 : 32);
    if (has('sharp')) return left ? 1 : (right ? 4 : 21);
    if (has('slight')) return left ? 2 : (right ? 5 : 21);
    if (left) return 0;
    if (right) return 3;
    return 21; // head / continue straight
  }
}
