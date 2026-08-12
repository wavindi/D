import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../data/repositories/run_repository.dart';
import '../../../domain/models/run_record.dart';

final runRepositoryProvider = Provider<RunRepository>((ref) => RunRepository());
final runHistoryProvider = FutureProvider<List<RunRecord>>(
  (ref) => ref.watch(runRepositoryProvider).getAll(),
);
final drivingStatsProvider = FutureProvider<DrivingStats>(
  (ref) => ref.watch(runRepositoryProvider).getStats(),
);
final territoriesProvider = FutureProvider<Set<String>>(
  (ref) => ref.watch(runRepositoryProvider).getTerritories(),
);

class RunState {
  const RunState({
    this.isActive = false,
    this.isPaused = false,
    this.isFreeDrive = false,
    this.autoTrackEnabled = false,
    this.elapsed = Duration.zero,
    this.currentSpeedKmh = 0,
    this.maxSpeedKmh = 0,
    this.averageSpeedKmh = 0,
    this.distanceMeters = 0,
    this.stoppedSeconds = 0,
    this.remainingMeters,
    this.eta,
    this.route = const [],
    this.samples = const [],
    this.startedAt,
    this.destination,
    this.destinationName,
    this.autoFinished = false,
    this.autoTrackStatus = 'Idle',
  });

  final bool isActive;
  final bool isPaused;
  final bool isFreeDrive;
  final bool autoTrackEnabled;
  final Duration elapsed;
  final double currentSpeedKmh;
  final double maxSpeedKmh;
  final double averageSpeedKmh;
  final double distanceMeters;
  final int stoppedSeconds;
  final double? remainingMeters;
  final Duration? eta;
  final List<LatLng> route;
  final List<SpeedSample> samples;
  final DateTime? startedAt;
  final LatLng? destination;
  final String? destinationName;
  final bool autoFinished;
  final String autoTrackStatus;

  RunState copyWith({
    bool? isActive,
    bool? isPaused,
    bool? isFreeDrive,
    bool? autoTrackEnabled,
    Duration? elapsed,
    double? currentSpeedKmh,
    double? maxSpeedKmh,
    double? averageSpeedKmh,
    double? distanceMeters,
    int? stoppedSeconds,
    double? remainingMeters,
    Duration? eta,
    List<LatLng>? route,
    List<SpeedSample>? samples,
    DateTime? startedAt,
    LatLng? destination,
    String? destinationName,
    bool? autoFinished,
    String? autoTrackStatus,
    bool clearEta = false,
    bool clearDestination = false,
  }) =>
      RunState(
        isActive: isActive ?? this.isActive,
        isPaused: isPaused ?? this.isPaused,
        isFreeDrive: isFreeDrive ?? this.isFreeDrive,
        autoTrackEnabled: autoTrackEnabled ?? this.autoTrackEnabled,
        elapsed: elapsed ?? this.elapsed,
        currentSpeedKmh: currentSpeedKmh ?? this.currentSpeedKmh,
        maxSpeedKmh: maxSpeedKmh ?? this.maxSpeedKmh,
        averageSpeedKmh: averageSpeedKmh ?? this.averageSpeedKmh,
        distanceMeters: distanceMeters ?? this.distanceMeters,
        stoppedSeconds: stoppedSeconds ?? this.stoppedSeconds,
        remainingMeters: remainingMeters ?? this.remainingMeters,
        eta: clearEta ? null : (eta ?? this.eta),
        route: route ?? this.route,
        samples: samples ?? this.samples,
        startedAt: startedAt ?? this.startedAt,
        destination: clearDestination ? null : (destination ?? this.destination),
        destinationName:
            clearDestination ? null : (destinationName ?? this.destinationName),
        autoFinished: autoFinished ?? this.autoFinished,
        autoTrackStatus: autoTrackStatus ?? this.autoTrackStatus,
      );
}

final activeRunProvider = NotifierProvider<ActiveRunController, RunState>(
  ActiveRunController.new,
);

class ActiveRunController extends Notifier<RunState> {
  static const _maxAccuracyMeters = 35.0;
  static const _maxJumpMeters = 80.0;
  static const _arrivalRadiusMeters = 45.0;
  static const _autoStartSpeedKmh = 22.0;
  static const _autoStartHold = Duration(seconds: 6);
  static const _autoStopSpeedKmh = 6.0;
  static const _autoStopHold = Duration(minutes: 2);

  Timer? _timer;
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<Position>? _autoWatchSubscription;
  Duration _pausedAccumulated = Duration.zero;
  DateTime? _pauseStartedAt;
  DateTime? _runClockStart;
  DateTime? _movingSince;
  DateTime? _stoppedSince;
  int _stoppedSeconds = 0;

  @override
  RunState build() {
    ref.onDispose(() {
      unawaited(_stopTracking());
      unawaited(_stopAutoWatch());
    });
    return const RunState();
  }

  Future<void> start({
    LatLng? destination,
    String? destinationName,
    bool freeDrive = false,
  }) async {
    if (state.isActive) return;
    await _ensureLocationAccess();
    final initial = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
    );
    final startedAt = DateTime.now();
    _runClockStart = startedAt;
    _pausedAccumulated = Duration.zero;
    _pauseStartedAt = null;
    _stoppedSeconds = 0;
    _movingSince = null;
    _stoppedSince = null;
    final point = LatLng(initial.latitude, initial.longitude);
    state = RunState(
      isActive: true,
      isPaused: false,
      isFreeDrive: freeDrive || destination == null,
      autoTrackEnabled: state.autoTrackEnabled,
      startedAt: startedAt,
      route: [point],
      samples: [
        SpeedSample(
          lat: point.latitude,
          lng: point.longitude,
          speedKmh: math.max(0, initial.speed * 3.6),
        ),
      ],
      destination: destination,
      destinationName: freeDrive ? 'Free drive' : destinationName,
      remainingMeters: destination == null
          ? null
          : Geolocator.distanceBetween(
              initial.latitude,
              initial.longitude,
              destination.latitude,
              destination.longitude,
            ),
      autoTrackStatus: freeDrive ? 'Auto free-drive' : 'Manual run',
    );
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tickClock());
    const settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 2,
    );
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(_onPosition);
  }

  Future<void> setAutoTrackEnabled(bool enabled) async {
    state = state.copyWith(
      autoTrackEnabled: enabled,
      autoTrackStatus: enabled ? 'Watching for movement…' : 'Idle',
    );
    if (enabled) {
      await _startAutoWatch();
    } else {
      await _stopAutoWatch();
    }
  }

  Future<void> _startAutoWatch() async {
    await _stopAutoWatch();
    await _ensureLocationAccess();
    _autoWatchSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 3,
      ),
    ).listen((position) async {
      if (state.isActive || !state.autoTrackEnabled) return;
      final speed = math.max(0.0, position.speed * 3.6);
      final now = DateTime.now();
      if (speed >= _autoStartSpeedKmh) {
        _movingSince ??= now;
        final held = now.difference(_movingSince!);
        state = state.copyWith(
          autoTrackStatus:
              'Drive detected… ${held.inSeconds}s / ${_autoStartHold.inSeconds}s',
          currentSpeedKmh: speed,
        );
        if (held >= _autoStartHold) {
          await start(freeDrive: true);
        }
      } else {
        _movingSince = null;
        state = state.copyWith(
          autoTrackStatus: 'Watching for movement…',
          currentSpeedKmh: speed,
        );
      }
    });
  }

  Future<void> _stopAutoWatch() async {
    await _autoWatchSubscription?.cancel();
    _autoWatchSubscription = null;
    _movingSince = null;
  }

  void pause() {
    if (!state.isActive || state.isPaused) return;
    _pauseStartedAt = DateTime.now();
    state = state.copyWith(isPaused: true, currentSpeedKmh: 0, clearEta: true);
  }

  void resume() {
    if (!state.isActive || !state.isPaused) return;
    if (_pauseStartedAt != null) {
      _pausedAccumulated += DateTime.now().difference(_pauseStartedAt!);
      _pauseStartedAt = null;
    }
    state = state.copyWith(isPaused: false);
    _tickClock();
  }

  void _tickClock() {
    if (!state.isActive || state.isPaused || _runClockStart == null) return;
    final elapsed =
        DateTime.now().difference(_runClockStart!) - _pausedAccumulated;
    final avg = elapsed.inSeconds <= 0
        ? 0.0
        : (state.distanceMeters / 1000) / (elapsed.inSeconds / 3600);
    state = state.copyWith(
      elapsed: elapsed.isNegative ? Duration.zero : elapsed,
      averageSpeedKmh: math.max(0, avg),
      stoppedSeconds: _stoppedSeconds,
      eta: _estimateEta(state.remainingMeters, avg, state.currentSpeedKmh),
    );
  }

  void _onPosition(Position position) {
    if (!state.isActive || state.isPaused) return;
    if (position.accuracy > _maxAccuracyMeters) return;

    final point = LatLng(position.latitude, position.longitude);
    final route = [...state.route];
    final samples = [...state.samples];
    var distance = state.distanceMeters;
    if (route.isNotEmpty) {
      final previous = route.last;
      final step = Geolocator.distanceBetween(
        previous.latitude,
        previous.longitude,
        point.latitude,
        point.longitude,
      );
      if (step > _maxJumpMeters) return;
      if (step < 1.5 && (position.speed * 3.6) < 1.5) {
        // count near-stop
      } else {
        distance += step;
      }
    }
    route.add(point);
    final speed = math.max(0.0, position.speed * 3.6);
    samples.add(SpeedSample(lat: point.latitude, lng: point.longitude, speedKmh: speed));

    final now = DateTime.now();
    if (speed < _autoStopSpeedKmh) {
      _stoppedSince ??= now;
      _stoppedSeconds += 1;
      if (state.isFreeDrive &&
          state.autoTrackEnabled &&
          now.difference(_stoppedSince!) >= _autoStopHold &&
          distance > 200) {
        state = state.copyWith(autoFinished: true, isPaused: true, currentSpeedKmh: 0);
        unawaited(_stopTracking());
        return;
      }
    } else {
      _stoppedSince = null;
    }

    final remaining = state.destination == null
        ? null
        : Geolocator.distanceBetween(
            point.latitude,
            point.longitude,
            state.destination!.latitude,
            state.destination!.longitude,
          );
    final elapsed = state.elapsed;
    final avg = elapsed.inSeconds <= 0
        ? 0.0
        : (distance / 1000) / (elapsed.inSeconds / 3600);

    state = state.copyWith(
      currentSpeedKmh: speed,
      maxSpeedKmh: math.max(state.maxSpeedKmh, speed),
      averageSpeedKmh: math.max(0, avg),
      distanceMeters: distance,
      remainingMeters: remaining,
      stoppedSeconds: _stoppedSeconds,
      eta: _estimateEta(remaining, avg, speed),
      route: List.unmodifiable(route),
      samples: List.unmodifiable(samples),
    );

    if (remaining != null && remaining <= _arrivalRadiusMeters) {
      state = state.copyWith(autoFinished: true, isPaused: true, currentSpeedKmh: 0);
      unawaited(_stopTracking());
    }
  }

  Duration? _estimateEta(
    double? remainingMeters,
    double avgKmh,
    double currentKmh,
  ) {
    if (remainingMeters == null || remainingMeters <= 0) return Duration.zero;
    final speed = currentKmh > 5 ? currentKmh : (avgKmh > 5 ? avgKmh : 0);
    if (speed <= 0) return null;
    final hours = (remainingMeters / 1000) / speed;
    return Duration(seconds: (hours * 3600).round());
  }

  Future<RunRecord> finish() async {
    if (!state.isActive || state.startedAt == null) {
      throw StateError('There is no active run.');
    }
    if (state.isPaused && _pauseStartedAt != null) {
      _pausedAccumulated += DateTime.now().difference(_pauseStartedAt!);
      _pauseStartedAt = null;
    }
    final elapsed = _runClockStart == null
        ? state.elapsed
        : DateTime.now().difference(_runClockStart!) - _pausedAccumulated;
    final safeElapsed = elapsed.isNegative ? Duration.zero : elapsed;
    final avg = safeElapsed.inSeconds <= 0
        ? 0.0
        : (state.distanceMeters / 1000) / (safeElapsed.inSeconds / 3600);
    final finalState = state.copyWith(
      isActive: false,
      isPaused: false,
      currentSpeedKmh: 0,
      elapsed: safeElapsed,
      averageSpeedKmh: math.max(0, avg),
      stoppedSeconds: _stoppedSeconds,
    );
    state = finalState;
    await _stopTracking();
    final run = RunRecord(
      startedAt: finalState.startedAt!,
      durationSeconds: finalState.elapsed.inSeconds,
      distanceMeters: finalState.distanceMeters,
      topSpeedKmh: finalState.maxSpeedKmh,
      averageSpeedKmh: finalState.averageSpeedKmh,
      destinationName: finalState.destinationName,
      stoppedSeconds: finalState.stoppedSeconds,
      samples: finalState.samples,
    );
    final saved = await ref.read(runRepositoryProvider).save(run);
    ref.invalidate(runHistoryProvider);
    ref.invalidate(drivingStatsProvider);
    ref.invalidate(territoriesProvider);
    final keepAuto = finalState.autoTrackEnabled;
    state = RunState(
      autoTrackEnabled: keepAuto,
      autoTrackStatus: keepAuto ? 'Watching for movement…' : 'Idle',
    );
    if (keepAuto) {
      await _startAutoWatch();
    }
    return saved;
  }

  Future<void> _ensureLocationAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('Turn on Location Services to start a run.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw StateError('Location permission is required to record a run.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw StateError('Enable location permission for D in system settings.');
    }
  }

  Future<void> _stopTracking() async {
    _timer?.cancel();
    _timer = null;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }
}
