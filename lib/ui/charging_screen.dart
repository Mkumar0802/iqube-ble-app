import 'package:flutter/material.dart';

import '../ble/vehicle_service.dart';
import '../services/charge_tracker.dart';
import '../services/range_estimator.dart';
import 'common.dart';

class ChargingScreen extends StatelessWidget {
  const ChargingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Charging')),
      body: ListenableBuilder(
        listenable:
            Listenable.merge([VehicleService.instance, ChargeTracker.instance]),
        builder: (context, _) {
          final pct = VehicleService.instance.batteryPercent;
          final charge = ChargeTracker.instance;
          final theme = Theme.of(context);
          if (pct == null) {
            return const Center(
                child: Text('Connect to your scooter to see charging info'));
          }
          final charging = charge.isCharging;
          final range = RangeEstimate.forBattery(pct)!;
          final rateSource = charge.measuredRate != null
              ? 'measured now'
              : charge.learnedRatePctPerHour != null
                  ? 'from last charge'
                  : 'default — set in Settings';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      SizedBox(
                        width: 200,
                        height: 200,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CircularProgressIndicator(
                              value: pct / 100,
                              strokeWidth: 16,
                              strokeCap: StrokeCap.round,
                              color: batteryColor(pct),
                              backgroundColor:
                                  theme.colorScheme.surfaceContainerHighest,
                            ),
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (charging)
                                    const Icon(Icons.bolt,
                                        color: batteryGreen, size: 32),
                                  Text('$pct%',
                                      style: theme.textTheme.displayMedium
                                          ?.copyWith(fontWeight: FontWeight.w800)),
                                  Text('${range.ecoKm} km (Eco)',
                                      style: theme.textTheme.bodyMedium),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        pct >= 100
                            ? 'Fully charged'
                            : charging
                                ? 'Charging'
                                : 'Not charging',
                        style: theme.textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
              ),
              const SectionTitle('Charge time'),
              Card(
                child: Column(
                  children: [
                    Row(children: [
                      Expanded(
                          child: StatTile(
                              icon: Icons.battery_5_bar,
                              label: 'To 80%',
                              value: pct >= 80
                                  ? 'Done'
                                  : formatDuration(charge.timeTo(pct, 80)))),
                      Expanded(
                          child: StatTile(
                              icon: Icons.battery_full,
                              label: 'To 100%',
                              value: pct >= 100
                                  ? 'Done'
                                  : formatDuration(charge.timeTo(pct, 100)))),
                    ]),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.speed),
                      title: Text(
                          '${charge.ratePctPerHour.toStringAsFixed(1)} % per hour'),
                      subtitle: Text('Charge speed ($rateSource)'),
                    ),
                    if (charge.lastFullChargeAt != null)
                      ListTile(
                        leading: const Icon(Icons.history),
                        title: Text(
                            '${formatDate(charge.lastFullChargeAt!)}, ${formatTime(charge.lastFullChargeAt!)}'),
                        subtitle: const Text('Last full charge'),
                      ),
                  ],
                ),
              ),
              const SectionTitle('Battery today'),
              Card(
                child: charge.samples.isEmpty
                    ? const ListTile(title: Text('No changes recorded yet'))
                    : Column(
                        children: [
                          for (final s in charge.samples.reversed.take(12))
                            ListTile(
                              dense: true,
                              leading: Icon(Icons.circle,
                                  size: 12, color: batteryColor(s.$2)),
                              title: Text('${s.$2}%'),
                              trailing: Text(formatTime(s.$1)),
                            ),
                        ],
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Times are estimates from how fast the battery % rises. '
                  'Charging slows above 80%, so keep the app connected '
                  'while charging for the best numbers.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
