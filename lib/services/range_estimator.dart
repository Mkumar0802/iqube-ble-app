import '../rides/ride.dart';
import 'app_settings.dart';

/// Range from battery %. Starts from the configured full-charge range and
/// switches to your real km-per-% once enough rides have been recorded.
class RangeEstimate {
  final int ecoKm;
  final int powerKm;
  final bool learned;
  const RangeEstimate(this.ecoKm, this.powerKm, this.learned);

  static RangeEstimate? forBattery(int? percent) {
    if (percent == null) return null;
    final s = AppSettings.instance;
    final configuredEco = s.fullRangeEcoKm / 100;
    final learned = RideStore.instance.learnedKmPerPercent;
    // Learned figure reflects how you actually ride; scale Power by the
    // same factor so the two stay in proportion.
    final factor = learned == null ? 1.0 : learned / configuredEco;
    return RangeEstimate(
      (percent * configuredEco * factor).round(),
      (percent * s.fullRangePowerKm / 100 * factor).round(),
      learned != null,
    );
  }
}
