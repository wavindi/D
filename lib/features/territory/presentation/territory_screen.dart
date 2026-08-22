import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/racing_theme.dart';
import '../../../shared/widgets/race_widgets.dart';
import '../../../data/repositories/run_repository.dart';
import '../../run/application/run_providers.dart';

class TerritoryScreen extends ConsumerWidget {
  const TerritoryScreen({super.key, this.onMenu});
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final territories = ref.watch(territoriesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'TERRITORY',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: territories.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.blue),
        ),
        error: (e, _) => Center(child: Text('$e')),
        data: (cells) {
          final centers = cells
              .map(RunRepository.cellCenter)
              .map((c) => LatLng(c.$1, c.$2))
              .toList(growable: false);
          final center = centers.isEmpty
              ? const LatLng(36.8065, 10.1815)
              : centers[centers.length ~/ 2];
          return Stack(
            children: [
              FlutterMap(
                options: MapOptions(initialCenter: center, initialZoom: 12.5),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.d.racing.d',
                  ),
                  if (centers.isNotEmpty)
                    CircleLayer(
                      circles: [
                        for (final p in centers)
                          CircleMarker(
                            point: p,
                            radius: 10,
                            color: const Color(0xAA9B5CFF),
                            borderColor: const Color(0xFFD6B3FF),
                            borderStrokeWidth: 1.5,
                          ),
                      ],
                    ),
                ],
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 24,
                child: SafeArea(
                  top: false,
                  child: RaceEntrance(
                    child: NeonPanel(
                      color: RaceColors.magenta,
                      radius: 24,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.public_rounded,
                                color: RaceColors.magenta,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'WORLD TERRITORY',
                                style: TextStyle(
                                  color: RaceColors.magenta,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.4,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${cells.length}',
                            style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1,
                            ),
                          ),
                          const Text(
                            'territories claimed',
                            style: TextStyle(
                              color: RaceColors.muted,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Every road you drive claims grid cells on the map. Keep driving to expand your empire.',
                            style: TextStyle(color: RaceColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
