import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'frame_parser.dart';
import 'vehicle_service.dart';

/// Developer view of the raw frames the scooter sends, via the shared
/// [VehicleService] connection: the latest frame per DataId at the top,
/// then a log of every frame that changed.
class TelemetryScreen extends StatelessWidget {
  const TelemetryScreen({super.key});

  static String _hex(List<int> b) =>
      b.map((x) => x.toRadixString(16).padLeft(2, '0')).join(' ');

  @override
  Widget build(BuildContext context) {
    const mono = AppText.mono;
    return Scaffold(
      appBar: AppBar(title: const Text('Raw scooter data')),
      body: ListenableBuilder(
        listenable: VehicleService.instance,
        builder: (context, _) {
          final v = VehicleService.instance;
          if (!v.isConnected && v.frameLog.isEmpty) {
            return const Center(child: Text('Scooter not connected'));
          }
          final ids = v.lastFrames.keys.toList()..sort();
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Text('Latest per type', style: Theme.of(context).textTheme.titleSmall),
              for (final id in ids)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                      '${FrameParser.labelForDataId(id).split(' ').first.padRight(10)} '
                      '${_hex(v.lastFrames[id]!)}',
                      style: mono),
                ),
              const Divider(),
              Text('Changes (newest first)',
                  style: Theme.of(context).textTheme.titleSmall),
              for (final line in v.frameLog)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(line, style: mono),
                ),
            ],
          );
        },
      ),
    );
  }
}
