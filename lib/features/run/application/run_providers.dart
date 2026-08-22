import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/utils/gps_filter.dart';
import '../../../data/repositories/run_repository.dart';
import '../../../domain/models/run_record.dart';

final runRepositoryProvider = Provider.autoDispose<RunRepository>(
  (ref) => RunRepository(),
);
final runHistoryProvider = FutureProvider.autoDispose<List<RunRecord>>(
  (ref) => ref.watch(runRepositoryProvider).getAll(),
);
final drivingStatsProvider = FutureProvider.autoDispose<DrivingStats>(
  (ref) => ref.watch(runRepositoryProvider).getStats(),
);
final territoriesProvider = FutureProvider.autoDispose<Set<String>>(
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
  }) => RunState(
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
    destinationName: clearDestination
        ? null
        : (destinationName ?? this.destinationName),
    autoFinished: autoFinished ?? this.autoFinished,
    autoTrackStatus: autoTrackStatus ?? this.autoTrackStatus,
  );
}

final activeRunProvider = NotifierProvider<ActiveRunController, RunState>(
  ActiveRunController.new,
);

class ActiveRunController extends Notifier<RunState> {
  static const _maxAccuracyMeters = 35.0;
  static const _arrivalRadiusMeters = 45.0;
  static const _autoStartSpeedKmh = 22.0;
  static const _autoStartHold = Duration(seconds: 6);
  static const _autoStopSpeedKmh = 6.0;
  static const _autoStopHold = Duration(minutes: 2);
  static const _maximumSamples = 10_000;
  static const _maximumPositionAge = Duration(seconds: 15);

  Timer? _timer;
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<Position>? _autoWatchSubscription;
  Duration _pausedAccumulated = Duration.zero;
  DateTime? _pauseStartedAt;
  DateTime? _runClockStart;
  DateTime? _movingSince;
  DateTime? _stoppedSince;
  DateTime? _endedAt;
  Duration _stoppedAccumulated = Duration.zero;
  bool _starting = false;
  LatLng? _lastTrackedPoint;
  DateTime? _lastTrackedAt;
  double _lastAccuracyMeters = 0;

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
    if (state.isActive || _starting) return;
    _starting = true;
    try {
      await _start(
        destination: destination,
        destinationName: destinationName,
        freeDrive: freeDrive,
      );
    } finally {
      _starting = false;
    }
  }

  Future<void> _start({
    LatLng? destination,
    String? destinationName,
    required bool freeDrive,
  }) async {
    await _stopAutoWatch();
    await _ensureLocationAccess();
    final initial = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
    );
    final startedAt = DateTime.now();
    _runClockStart = startedAt;
    _pausedAccumulated = Duration.zero;
    _pauseStartedAt = null;
    _endedAt = null;
    _stoppedAccumulated = Duration.zero;
    _movingSince = null;
    _stoppedSince = null;
    final point = LatLng(initial.latitude, initial.longitude);
    _lastTrackedPoint = point;
    _lastTrackedAt = initial.timestamp;
    _lastAccuracyMeters = initial.accuracy;
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
      destinationName: freeDrive
          ? 'From current location'
          : (destinationName ?? 'Destination run'),
      remainingMeters: destination == null
          ? null
          : Geolocator.distanceBetween(
              initial.latitude,
              initial.longitude,
              destination.latitude,
              destination.longitude,
            ),
      autoTrackStatus: freeDrive
          ? 'Recording from your location'
          : 'Manual run',
    );
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tickClock());
    const settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 2,
    );
    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: settings).listen(
          _onPosition,
          onError: (Object error) {
            state = state.copyWith(autoTrackStatus: 'GPS error: $error');
          },
        );
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
    _autoWatchSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 3,
          ),
        ).listen((position) async {
          if (state.isActive || _starting || !state.autoTrackEnabled) return;
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
              try {
                await start(freeDrive: true);
              } catch (error) {
                state = state.copyWith(
                  autoTrackStatus: 'Could not start: $error',
                );
                if (state.autoTrackEnabled && !state.isActive) {
                  await _startAutoWatch();
                }
              }
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
    final now = DateTime.now();
    _finishStop(now);
    _pauseStartedAt = now;
    state = state.copyWith(
      isPaused: true,
      currentSpeedKmh: 0,
      stoppedSeconds: _currentStoppedSeconds(now),
      clearEta: true,
    );
  }

  void resume() {
    if (!state.isActive || !state.isPaused) return;
    if (_pauseStartedAt != null) {
      _pausedAccumulated += DateTime.now().difference(_pauseStartedAt!);
      _pauseStartedAt = null;
    }
    _endedAt = null;
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
    final now = DateTime.now();
    state = state.copyWith(
      elapsed: elapsed.isNegative ? Duration.zero : elapsed,
      averageSpeedKmh: math.max(0, avg),
      stoppedSeconds: _currentStoppedSeconds(now),
      eta: _estimateEta(state.remainingMeters, avg, state.currentSpeedKmh),
    );
  }

  void _onPosition(Position position) {
    if (!state.isActive || state.isPaused) return;
    if (position.accuracy > _maxAccuracyMeters) return;
    if (DateTime.now().difference(position.timestamp).abs() >
        _maximumPositionAge) {
      return;
    }

    final point = LatLng(position.latitude, position.longitude);
    final route = [...state.route];
    final samples = [...state.samples];
    var distance = state.distanceMeters;
    final speed = math.max(0.0, position.speed * 3.6);
    if (_lastTrackedPoint != null) {
      final previous = _lastTrackedPoint!;
      final step = Geolocator.distanceBetween(
        previous.latitude,
        previous.longitude,
        point.latitude,
        point.longitude,
      );
      final previousTimestamp = _lastTrackedAt ?? position.timestamp;
      final plausible = isPlausibleGpsStep(
        distanceMeters: step,
        elapsed: position.timestamp.difference(previousTimestamp).abs(),
        previousSpeedKmh: state.currentSpeedKmh,
        currentSpeedMps: position.speed,
        previousAccuracyMeters: _lastAccuracyMeters,
        currentAccuracyMeters: position.accuracy,
      );
      if (!plausible) {
        // Advance the comparison point so one bad GPS reading cannot cause all
        // subsequent updates to be rejected against an increasingly old point.
        _lastTrackedPoint = point;
        _lastTrackedAt = position.timestamp;
        _lastAccuracyMeters = position.accuracy;
        state = state.copyWith(currentSpeedKmh: speed);
        return;
      }
      if (step >= 1.5 || (position.speed * 3.6) >= 1.5) {
        distance += step;
      }
    }
    _lastTrackedPoint = point;
    _lastTrackedAt = position.timestamp;
    _lastAccuracyMeters = position.accuracy;
    if (route.length < _maximumSamples) route.add(point);
    if (samples.length < _maximumSamples) {
      samples.add(
        SpeedSample(lat: point.latitude, lng: point.longitude, speedKmh: speed),
      );
    }

    final now = DateTime.now();
    if (speed < _autoStopSpeedKmh) {
      _stoppedSince ??= now;
      if (state.isFreeDrive &&
          state.autoTrackEnabled &&
          now.difference(_stoppedSince!) >= _autoStopHold &&
          distance > 200) {
        _endedAt = now;
        state = state.copyWith(
          autoFinished: true,
          isPaused: true,
          currentSpeedKmh: 0,
          stoppedSeconds: _currentStoppedSeconds(now),
        );
        unawaited(_stopTracking());
        return;
      }
    } else {
      _finishStop(now);
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
      stoppedSeconds: _currentStoppedSeconds(now),
      eta: _estimateEta(remaining, avg, speed),
      route: List.unmodifiable(route),
      samples: List.unmodifiable(samples),
    );

    if (remaining != null && remaining <= _arrivalRadiusMeters) {
      _endedAt = now;
      state = state.copyWith(
        autoFinished: true,
        isPaused: true,
        currentSpeedKmh: 0,
        stoppedSeconds: _currentStoppedSeconds(now),
      );
      unawaited(_stopTracking());
    }
  }

  void _finishStop(DateTime now) {
    if (_stoppedSince == null) return;
    _stoppedAccumulated += now.difference(_stoppedSince!);
    _stoppedSince = null;
  }

  int _currentStoppedSeconds(DateTime now) {
    final currentStop = _stoppedSince == null
        ? Duration.zero
        : now.difference(_stoppedSince!);
    return (_stoppedAccumulated + currentStop).inSeconds;
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
    final endedAt = _endedAt ?? DateTime.now();
    if (state.isPaused && _pauseStartedAt != null) {
      _pausedAccumulated += endedAt.difference(_pauseStartedAt!);
      _pauseStartedAt = null;
    }
    _finishStop(endedAt);
    final elapsed = _runClockStart == null
        ? state.elapsed
        : endedAt.difference(_runClockStart!) - _pausedAccumulated;
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
      stoppedSeconds: _currentStoppedSeconds(endedAt),
    );
    state = finalState;
    await _stopTracking();
    _lastTrackedPoint = null;
    _lastTrackedAt = null;
    _lastAccuracyMeters = 0;
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
