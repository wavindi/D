import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/models/run_record.dart';

Color speedColor(double kmh) {
  if (kmh < 50) return const Color(0xFF2EE59D);
  if (kmh < 90) return const Color(0xFF7CFF6B);
  if (kmh < 130) return const Color(0xFFFFC857);
  return const Color(0xFFFF4D6D);
}

List<Polyline> speedPolylines(List<SpeedSample> samples) {
  if (samples.length < 2) return const [];
  final polylines = <Polyline>[];
  for (var i = 1; i < samples.length; i++) {
    final a = samples[i - 1];
    final b = samples[i];
    final speed = (a.speedKmh + b.speedKmh) / 2;
    polylines.add(
      Polyline(
        points: [LatLng(a.lat, a.lng), LatLng(b.lat, b.lng)],
        color: speedColor(speed),
        strokeWidth: 6,
      ),
    );
  }
  return polylines;
}

class SpeedDistributionBar extends StatelessWidget {
  const SpeedDistributionBar({super.key, required this.distribution});
  final SpeedDistribution distribution;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('<50', distribution.under50, const Color(0xFF2EE59D)),
      ('50-90', distribution.from50to90, const Color(0xFF7CFF6B)),
      ('90-130', distribution.from90to130, const Color(0xFFFFC857)),
      ('130+', distribution.over130, const Color(0xFFFF4D6D)),
    ];
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 14,
            child: Row(
              children: [
                for (final item in items)
                  if (item.$2 > 0)
                    Expanded(
                      flex: (item.$2 * 1000).round().clamp(1, 1000),
                      child: Container(color: item.$3),
                    ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final item in items)
              Expanded(
                child: Column(
                  children: [
                    Text(
                      item.$1,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(item.$2 * 100).round()}%',
                      style: TextStyle(
                        color: item.$3,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
