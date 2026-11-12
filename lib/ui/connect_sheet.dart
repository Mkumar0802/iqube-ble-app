import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../ble/vehicle_service.dart';
import 'common.dart';
import 'widgets/kit.dart';
import 'widgets/scale_on_tap.dart';
import 'widgets/scanning_radar.dart';

/// Bottom sheet that scans and lets the user pick their scooter.
Future<void> showConnectSheet(BuildContext context) {
  final c = AppColors.of(context);
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: c.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _ConnectSheet(),
  );
}

class _ConnectSheet extends StatefulWidget {
  const _ConnectSheet();

  @override
  State<_ConnectSheet> createState() => _ConnectSheetState();
}

class _ConnectSheetState extends State<_ConnectSheet> {
  late final Stream<List<ScanResult>> _results = VehicleService.instance.scan();
  bool _showAll = false;

  @override
  void dispose() {
    VehicleService.instance.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = AppColors.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [c.surface, c.background],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Connect your iQube', style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  'Switch the scooter on and close the TVS Connect app — '
                  'the scooter accepts only one phone at a time.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<List<ScanResult>>(
              stream: _results,
              builder: (context, snap) {
                final all = snap.data ?? const [];
                final list = _showAll
                    ? all
                    : all.where(VehicleService.looksLikeScooter).toList();
                if (list.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ScanningRadar(
                            size: 160,
                            scanning: true,
                            color: c.brand,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Looking for your scooter...',
                            style: theme.textTheme.titleSmall
                                ?.copyWith(color: c.onSurfaceMuted),
                          ),
                          if (!_showAll && all.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            ScaleOnTap(
                              child: TextButton(
                                onPressed: () =>
                                    setState(() => _showAll = true),
                                child: Text('Show all ${all.length} devices'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: [
                    for (var i = 0; i < list.length; i++) ...[
                      Reveal(
                        index: i,
                        child: ScaleOnTap(
                          onTap: () {
                            VehicleService.instance.connect(
                              list[i].device,
                              name: list[i].device.platformName,
                            );
                            Navigator.of(context).pop();
                          },
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: c.brand.withValues(alpha: 0.12),
                              child: Icon(
                                VehicleService.looksLikeScooter(list[i])
                                    ? Icons.electric_moped
                                    : Icons.bluetooth,
                                color: c.brand,
                              ),
                            ),
                            title: Text(
                              list[i].device.platformName.isEmpty
                                  ? '(unnamed)'
                                  : list[i].device.platformName,
                              style: theme.textTheme.titleMedium,
                            ),
                            subtitle: Text(
                              '${list[i].device.remoteId}  •  ${list[i].rssi} dBm',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: c.onSurfaceMuted),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _RssiBars(rssi: list[i].rssi),
                                const SizedBox(width: 8),
                                Icon(Icons.chevron_right,
                                    color: c.onSurfaceMuted),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (!_showAll)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: ScaleOnTap(
                          child: TextButton(
                            onPressed: () => setState(() => _showAll = true),
                            child: const Text('Show all devices'),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 4-bar RSSI signal strength indicator (-100 to -30 dBm).
class _RssiBars extends StatelessWidget {
  const _RssiBars({required this.rssi});

  final int rssi;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    // Levels:
    // 4 bars: >= -60 dBm (Excellent)
    // 3 bars: >= -72 dBm (Good)
    // 2 bars: >= -85 dBm (Fair)
    // 1 bar:  < -85 dBm  (Weak)
    final int activeBars;
    final Color barColor;
    if (rssi >= -60) {
      activeBars = 4;
      barColor = c.energy;
    } else if (rssi >= -72) {
      activeBars = 3;
      barColor = c.energy;
    } else if (rssi >= -85) {
      activeBars = 2;
      barColor = c.warning;
    } else {
      activeBars = 1;
      barColor = c.danger;
    }

    const heights = [4.0, 7.0, 10.0, 13.0];
    final inactiveColor = c.onSurfaceMuted.withValues(alpha: 0.22);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < 4; i++) ...[
          Container(
            width: 3,
            height: heights[i],
            decoration: BoxDecoration(
              color: i < activeBars ? barColor : inactiveColor,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
          if (i < 3) const SizedBox(width: 2),
        ],
      ],
    );
  }
}
