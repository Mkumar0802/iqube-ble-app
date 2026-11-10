import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../ble/vehicle_service.dart';

/// Bottom sheet that scans and lets the user pick their scooter.
Future<void> showConnectSheet(BuildContext context) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _ConnectSheet(),
    );

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
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
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
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<List<ScanResult>>(
              stream: _results,
              builder: (context, snap) {
                final all = snap.data ?? const [];
                final list = _showAll
                    ? all
                    : all.where(VehicleService.looksLikeScooter).toList();
                if (list.isEmpty) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      const Text('Looking for your scooter...'),
                      if (!_showAll && all.isNotEmpty)
                        TextButton(
                          onPressed: () => setState(() => _showAll = true),
                          child: Text('Show all ${all.length} devices'),
                        ),
                    ],
                  );
                }
                return ListView(
                  children: [
                    for (final r in list)
                      ListTile(
                        leading: CircleAvatar(
                          child: Icon(VehicleService.looksLikeScooter(r)
                              ? Icons.electric_moped
                              : Icons.bluetooth),
                        ),
                        title: Text(r.device.platformName.isEmpty
                            ? '(unnamed)'
                            : r.device.platformName),
                        subtitle: Text('${r.device.remoteId}  •  ${r.rssi} dBm'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          VehicleService.instance
                              .connect(r.device, name: r.device.platformName);
                          Navigator.of(context).pop();
                        },
                      ),
                    if (!_showAll)
                      TextButton(
                        onPressed: () => setState(() => _showAll = true),
                        child: const Text('Show all devices'),
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
