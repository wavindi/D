import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/run_repository.dart';
import '../../run/application/run_providers.dart';

class TerritoryScreen extends ConsumerWidget {
  const TerritoryScreen({super.key});

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
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.panel,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: const Color(0xFF9B5CFF).withValues(alpha: .45),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'WORLD TERRITORY',
                          style: TextStyle(
                            color: Color(0xFFD6B3FF),
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${cells.length} territories claimed',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Every road you drive claims grid cells on the map. Keep driving to expand your empire.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ],
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
