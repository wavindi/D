import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_theme.dart';
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
        automaticallyImplyLeading: onMenu == null,
        leading: onMenu == null
            ? null
            : IconButton(
                onPressed: onMenu,
                icon: const Icon(Icons.menu_rounded),
              ),
        title: Text(
          'TURF WAR // GRID',
          style: GoogleFonts.orbitron(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
            fontSize: 17,
          ),
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
                            color: AppColors.blue.withValues(alpha: .38),
                            borderColor: AppColors.blue,
                            borderStrokeWidth: 1.8,
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
                      color: AppColors.panel.withValues(alpha: .95),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.blue.withValues(alpha: .45),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'YOUR SECTOR // CYAN GRID',
                          style: GoogleFonts.rajdhani(
                            color: AppColors.blue,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.6,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${cells.length.toString().padLeft(3, '0')} CELLS CLAIMED',
                          style: GoogleFonts.orbitron(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Cyan cells are yours. Rival sectors will appear in red when multiplayer sync is live.',
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
