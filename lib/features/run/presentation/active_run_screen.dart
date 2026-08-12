import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/led_button.dart';
import '../application/run_providers.dart';
import 'scoreboard_screen.dart';

class ActiveRunScreen extends ConsumerStatefulWidget {
  const ActiveRunScreen({super.key});

  @override
  ConsumerState<ActiveRunScreen> createState() => _ActiveRunScreenState();
}

class _ActiveRunScreenState extends ConsumerState<ActiveRunScreen> {
  bool _finishing = false;

  Future<void> _finish() async {
    setState(() => _finishing = true);
    try {
      final record = await ref.read(activeRunProvider.notifier).finish();
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => ScoreboardScreen(run: record)),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save run: $error')));
        setState(() => _finishing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Stack(
          children: [
            const _TrackingMap(),
            const SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  children: [
                    _RunStatus(),
                    SizedBox(height: 12),
                    _SpeedHud(),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _ElapsedHud()),
                        SizedBox(width: 12),
                        Expanded(child: _MaxSpeedHud()),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: SafeArea(
                top: false,
                child: LedButton(
                  label: 'FINISH RUN',
                  danger: true,
                  busy: _finishing,
                  onPressed: _finish,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackingMap extends ConsumerStatefulWidget {
  const _TrackingMap();

  @override
  ConsumerState<_TrackingMap> createState() => _TrackingMapState();
}

class _TrackingMapState extends ConsumerState<_TrackingMap> {
  final _controller = MapController();

  @override
  void initState() {
    super.initState();
    ref.listenManual<List<LatLng>>(
      activeRunProvider.select((state) => state.route),
      (previous, next) {
        final previousLast = previous == null || previous.isEmpty
            ? null
            : previous.last;
        if (next.isNotEmpty && previousLast != next.last) {
          _controller.move(next.last, 17);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final route = ref.watch(activeRunProvider.select((state) => state.route));
    final destination = ref.watch(
      activeRunProvider.select((state) => state.destination),
    );
    final initial = route.isEmpty ? const LatLng(36.8065, 10.1815) : route.last;
    return FlutterMap(
      mapController: _controller,
      options: MapOptions(initialCenter: initial, initialZoom: 17),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.d.racing.d',
        ),
        if (route.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(points: route, color: AppColors.blue, strokeWidth: 7),
            ],
          ),
        if (route.isNotEmpty)
          CircleLayer(
            circles: [
              CircleMarker(
                point: route.last,
                radius: 9,
                color: AppColors.blue,
                borderColor: Colors.white,
                borderStrokeWidth: 2,
              ),
            ],
          ),
        if (destination != null)
          MarkerLayer(
            markers: [
              Marker(
                point: destination,
                width: 52,
                height: 52,
                child: const Icon(
                  Icons.flag_rounded,
                  color: AppColors.danger,
                  size: 42,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _RunStatus extends StatelessWidget {
  const _RunStatus();

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(50),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulseDot(),
          SizedBox(width: 9),
          Text(
            'RUN ACTIVE',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.4),
          ),
        ],
      ),
    ),
  );
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _animation,
    child: const Icon(Icons.circle, size: 11, color: AppColors.blue),
  );
}

class _SpeedHud extends ConsumerWidget {
  const _SpeedHud();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speed = ref.watch(
      activeRunProvider.select((state) => state.currentSpeedKmh),
    );
    return _HudPanel(
      child: Column(
        children: [
          const Text(
            'CURRENT SPEED',
            style: TextStyle(color: AppColors.muted, letterSpacing: 2),
          ),
          Text(
            speed.toStringAsFixed(0),
            style: const TextStyle(
              fontSize: 76,
              height: 1.05,
              fontWeight: FontWeight.w900,
              color: AppColors.blue,
            ),
          ),
          const Text(
            'KM/H',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ElapsedHud extends ConsumerWidget {
  const _ElapsedHud();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final elapsed = ref.watch(
      activeRunProvider.select((state) => state.elapsed),
    );
    return _SmallStat(label: 'ELAPSED', value: formatDuration(elapsed));
  }
}

class _MaxSpeedHud extends ConsumerWidget {
  const _MaxSpeedHud();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final maxSpeed = ref.watch(
      activeRunProvider.select((state) => state.maxSpeedKmh),
    );
    return _SmallStat(
      label: 'MAX SPEED',
      value: '${maxSpeed.toStringAsFixed(0)} KM/H',
    );
  }
}

class _SmallStat extends StatelessWidget {
  const _SmallStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => _HudPanel(
    child: Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 11,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 6),
        FittedBox(
          child: Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    ),
  );
}

class _HudPanel extends StatelessWidget {
  const _HudPanel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.panel,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppColors.blue.withValues(alpha: .28)),
      boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 15)],
    ),
    child: child,
  );
}
