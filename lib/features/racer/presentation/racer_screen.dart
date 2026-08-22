import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/racing_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/race_widgets.dart';
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
    final (phaseLabel, phaseColor) = switch (state.phase) {
      RacerPhase.setup => ('RACER // SELECT ZONE', RaceColors.neonBlue),
      RacerPhase.armed => ('RACER // WAITING FOR ENTRY', RaceColors.neonBlue),
      RacerPhase.racing => ('RACE LIVE // EXIT TO FINISH', RaceColors.danger),
      RacerPhase.finishing => ('RACE COMPLETE // SAVING', RaceColors.neonBlue),
      RacerPhase.finished => ('RACE COMPLETE', RaceColors.lime),
    };
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
                    color: (active ? RaceColors.danger : RaceColors.neonBlue)
                        .withValues(alpha: .16),
                    borderColor: active ? RaceColors.danger : RaceColors.neonBlue,
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
                      color: RaceColors.neonBlue,
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
                  RaceStatusPill(
                    label: phaseLabel,
                    color: phaseColor,
                    pulse: active,
                    icon: Icons.speed_rounded,
                  ),
                  const SizedBox(height: 10),
                  if (active)
                    RaceEntrance(
                      child: _RaceHud(
                        state: state,
                        color: phaseColor,
                      ),
                    ),
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
              child: RaceEntrance(
                delay: const Duration(milliseconds: 120),
                child: _RacerConsole(
                  state: state,
                  onRadiusChanged: controller.setRadius,
                  onArm: controller.arm,
                  onCancel: controller.cancel,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RaceHud extends StatelessWidget {
  const _RaceHud({required this.state, required this.color});
  final RacerState state;
  final Color color;

  @override
  Widget build(BuildContext context) => NeonPanel(
        color: color,
        radius: 20,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _HudValue(label: 'TIME', value: formatDuration(state.elapsed)),
            _HudValue(
              label: 'DIST',
              value: formatDistance(state.distanceMeters),
            ),
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
              style: RaceText.label.copyWith(fontSize: 10),
            ),
            const SizedBox(height: 5),
            FittedBox(
              child: Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  fontSize: 16,
                ),
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
    final racing = state.phase == RacerPhase.racing ||
        state.phase == RacerPhase.armed;
    return NeonPanel(
      color: racing ? RaceColors.danger : RaceColors.neonBlue,
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.sports_score_rounded,
                color: RaceColors.neonBlue,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  state.trackName.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'CLOSED COURSE ONLY • Never operate this screen while driving.',
            style: TextStyle(
              color: RaceColors.danger,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            finishing
                ? 'Preserving your result and synchronizing it.'
                : state.phase == RacerPhase.armed
                ? state.outsideConfirmed
                    ? 'READY // Enter the zone to start.'
                    : 'Move fully outside the zone to confirm the start.'
                : active
                ? 'Cross the boundary to lock your result.'
                : 'Tap the map to place a zone. Start outside, then enter it.',
            style: const TextStyle(color: RaceColors.muted, fontSize: 12),
          ),
          if (!active && !finished && !finishing) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('ZONE', style: RaceText.label),
                Expanded(
                  child: Slider(
                    value: state.radiusMeters,
                    min: 50,
                    max: 200,
                    divisions: 6,
                    activeColor: RaceColors.neonBlue,
                    onChanged: onRadiusChanged,
                  ),
                ),
                Text(
                  '${state.radiusMeters.toStringAsFixed(0)}m',
                  style: const TextStyle(
                    color: RaceColors.neonBlue,
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
            RaceButton(
              label: 'SAVING RESULT',
              busy: true,
              onPressed: null,
            )
          else if (racing)
            RaceButton(
              label: active ? 'ABORT RACE' : 'CANCEL ARMING',
              danger: true,
              color: RaceColors.danger,
              onPressed: onCancel,
            )
          else
            RaceButton(
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
      padding: const EdgeInsets.all(12),
      decoration: RaceColors.panelDeco(
        border: delta != null && delta <= 0
            ? RaceColors.neonBlue
            : RaceColors.muted,
        radius: 14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            delta == null
                ? 'FIRST ZONE RESULT'
                : delta <= 0
                ? 'NEW PERSONAL BEST'
                : 'YOUR BEST',
            style: TextStyle(
              color: delta != null && delta <= 0
                  ? RaceColors.neonBlue
                  : RaceColors.muted,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatDuration(Duration(seconds: result.durationSeconds)),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 22,
            ),
          ),
          if (delta != null && delta > 0)
            Text(
              '${formatDuration(Duration(seconds: delta))} behind your best',
              style: const TextStyle(color: RaceColors.muted, fontSize: 12),
            ),
        ],
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
        decoration: BoxDecoration(
          color: RaceColors.danger.withValues(alpha: .9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
}
