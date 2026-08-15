import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/led_button.dart';
import '../../../shared/widgets/speed_widgets.dart';
import '../application/racer_providers.dart';

class RacerScreen extends ConsumerStatefulWidget {
  const RacerScreen({super.key, this.onMenu});
  final VoidCallback? onMenu;

  @override
  ConsumerState<RacerScreen> createState() => _RacerScreenState();
}

class _RacerScreenState extends ConsumerState<RacerScreen>
    with WidgetsBindingObserver {
  final _mapController = MapController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.listenManual(racerProvider.select((state) => state.currentPosition), (
      previous,
      next,
    ) {
      if (next != null && ref.read(racerProvider).phase == RacerPhase.racing) {
        _mapController.move(next, 16);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      unawaited(ref.read(racerProvider.notifier).interruptForBackground());
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(racerProvider);
    final controller = ref.read(racerProvider.notifier);
    final active = state.phase == RacerPhase.racing;
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: state.trackCenter,
              initialZoom: 14,
              onTap: (_, point) {
                if (state.phase == RacerPhase.setup ||
                    state.phase == RacerPhase.finished) {
                  controller.selectTrack(point);
                  _mapController.move(point, 14);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.d.racing.d',
              ),
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: state.trackCenter,
                    radius: state.radiusMeters,
                    useRadiusInMeter: true,
                    color: (active ? AppColors.danger : AppColors.blue)
                        .withValues(alpha: .16),
                    borderColor: active ? AppColors.danger : AppColors.blue,
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
              if (state.samples.length > 1)
                PolylineLayer(polylines: speedPolylines(state.samples)),
              MarkerLayer(
                markers: [
                  Marker(
                    point: state.trackCenter,
                    width: 52,
                    height: 52,
                    child: const Icon(
                      Icons.flag_rounded,
                      color: AppColors.blue,
                      size: 40,
                    ),
                  ),
                  if (state.currentPosition != null)
                    Marker(
                      point: state.currentPosition!,
                      width: 36,
                      height: 36,
                      child: const Icon(
                        Icons.navigation_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                ],
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: widget.onMenu,
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.panel,
                          foregroundColor: AppColors.blue,
                        ),
                        icon: const Icon(Icons.menu_rounded),
                      ),
                      const SizedBox(width: 10),
                      _StatusPill(phase: state.phase),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (active) _RaceHud(state: state),
                  if (state.error != null) _ErrorBanner(message: state.error!),
                ],
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: SafeArea(
              top: false,
              child: _RacerConsole(
                state: state,
                onRadiusChanged: controller.setRadius,
                onArm: controller.arm,
                onCancel: controller.cancel,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.phase});
  final RacerPhase phase;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (phase) {
      RacerPhase.setup => ('RACER // SELECT ZONE', AppColors.blue),
      RacerPhase.armed => ('RACER // WAITING FOR ENTRY', AppColors.blue),
      RacerPhase.racing => ('RACE LIVE // EXIT TO FINISH', AppColors.danger),
      RacerPhase.finishing => ('RACE COMPLETE // SAVING', AppColors.blue),
      RacerPhase.finished => ('RACE COMPLETE', AppColors.blue),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: .6)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _RaceHud extends StatelessWidget {
  const _RaceHud({required this.state});
  final RacerState state;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.panel,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.danger.withValues(alpha: .55)),
    ),
    child: Row(
      children: [
        _HudValue(label: 'TIME', value: formatDuration(state.elapsed)),
        _HudValue(label: 'DIST', value: formatDistance(state.distanceMeters)),
        _HudValue(
          label: 'MAX',
          value: '${state.topSpeedKmh.toStringAsFixed(0)} km/h',
        ),
      ],
    ),
  );
}

class _HudValue extends StatelessWidget {
  const _HudValue({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 10,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    ),
  );
}

class _RacerConsole extends StatelessWidget {
  const _RacerConsole({
    required this.state,
    required this.onRadiusChanged,
    required this.onArm,
    required this.onCancel,
  });
  final RacerState state;
  final ValueChanged<double> onRadiusChanged;
  final VoidCallback onArm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final finished = state.phase == RacerPhase.finished;
    final active = state.phase == RacerPhase.racing;
    final finishing = state.phase == RacerPhase.finishing;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel.withValues(alpha: .96),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.blue.withValues(alpha: .35)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            state.trackName.toUpperCase(),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'CLOSED COURSE ONLY • Never operate this screen while driving.',
            style: TextStyle(
              color: AppColors.danger,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            finishing
                ? 'Preserving your result and synchronizing it.'
                : active
                ? 'Cross the boundary to lock your result.'
                : 'Tap the map to place a zone. Start outside, then enter it.',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          if (!active && !finished && !finishing) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('ZONE'),
                Expanded(
                  child: Slider(
                    value: state.radiusMeters,
                    min: 50,
                    max: 200,
                    divisions: 6,
                    activeColor: AppColors.blue,
                    onChanged: onRadiusChanged,
                  ),
                ),
                Text(
                  '${state.radiusMeters.toStringAsFixed(0)}m',
                  style: const TextStyle(
                    color: AppColors.blue,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
          if (finished && state.result != null) ...[
            const SizedBox(height: 10),
            _Comparison(state: state),
          ],
          const SizedBox(height: 12),
          if (finishing)
            LedButton(label: 'SAVING RESULT', busy: true, onPressed: null)
          else if (active || state.phase == RacerPhase.armed)
            LedButton(
              label: active ? 'ABORT RACE' : 'CANCEL ARMING',
              danger: true,
              onPressed: onCancel,
            )
          else
            LedButton(
              label: finished ? 'ARM NEW RACE' : 'ARM RACER',
              icon: Icons.flag_rounded,
              onPressed: onArm,
            ),
        ],
      ),
    );
  }
}

class _Comparison extends StatelessWidget {
  const _Comparison({required this.state});
  final RacerState state;

  @override
  Widget build(BuildContext context) {
    final best = state.personalBestSeconds;
    final result = state.result!;
    final delta = best == null ? null : result.durationSeconds - best;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.black.withValues(alpha: .35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        delta == null
            ? 'FIRST ZONE RESULT • ${formatDuration(Duration(seconds: result.durationSeconds))}'
            : delta <= 0
            ? 'NEW PERSONAL BEST • ${formatDuration(Duration(seconds: result.durationSeconds))}'
            : '${formatDuration(Duration(seconds: delta))} BEHIND YOUR BEST',
        style: TextStyle(
          color: delta != null && delta <= 0 ? AppColors.blue : Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.all(10),
    color: AppColors.danger.withValues(alpha: .85),
    child: Text(message, style: const TextStyle(fontWeight: FontWeight.w700)),
  );
}
