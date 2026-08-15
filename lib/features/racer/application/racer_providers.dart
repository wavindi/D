import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../domain/models/run_record.dart';
import '../../run/application/run_providers.dart';
import 'geofence_gate.dart';

enum RacerPhase { setup, armed, racing, finishing, finished }

class RacerState {
  const RacerState({
    this.phase = RacerPhase.setup,
    this.trackCenter = const LatLng(36.8065, 10.1815),
    this.trackName = 'Custom Tunis track',
    this.radiusMeters = 90,
    this.currentPosition,
    this.elapsed = Duration.zero,
    this.distanceMeters = 0,
    this.topSpeedKmh = 0,
    this.samples = const [],
    this.startedAt,
    this.result,
    this.personalBestSeconds,
    this.error,
  });

  final RacerPhase phase;
  final LatLng trackCenter;
  final String trackName;
  final double radiusMeters;
  final LatLng? currentPosition;
  final Duration elapsed;
  final double distanceMeters;
  final double topSpeedKmh;
  final List<SpeedSample> samples;
  final DateTime? startedAt;
  final RunRecord? result;
  final int? personalBestSeconds;
  final String? error;

  RacerState copyWith({
    RacerPhase? phase,
    LatLng? trackCenter,
    String? trackName,
    double? radiusMeters,
    LatLng? currentPosition,
    Duration? elapsed,
    double? distanceMeters,
    double? topSpeedKmh,
    List<SpeedSample>? samples,
    DateTime? startedAt,
    RunRecord? result,
    int? personalBestSeconds,
    String? error,
    bool clearResult = false,
    bool clearError = false,
    bool clearPersonalBest = false,
  }) => RacerState(
    phase: phase ?? this.phase,
    trackCenter: trackCenter ?? this.trackCenter,
    trackName: trackName ?? this.trackName,
    radiusMeters: radiusMeters ?? this.radiusMeters,
    currentPosition: currentPosition ?? this.currentPosition,
    elapsed: elapsed ?? this.elapsed,
    distanceMeters: distanceMeters ?? this.distanceMeters,
    topSpeedKmh: topSpeedKmh ?? this.topSpeedKmh,
    samples: samples ?? this.samples,
    startedAt: startedAt ?? this.startedAt,
    result: clearResult ? null : (result ?? this.result),
    personalBestSeconds: clearPersonalBest
        ? null
        : (personalBestSeconds ?? this.personalBestSeconds),
    error: clearError ? null : (error ?? this.error),
  );
}

final racerProvider = NotifierProvider<RacerController, RacerState>(
  RacerController.new,
);

class RacerController extends Notifier<RacerState> {
  static const _maxAccuracyMeters = 40.0;
  static const _maximumPositionAge = Duration(seconds: 15);
  static const _minimumRaceDuration = Duration(seconds: 3);
  static const _minimumRaceDistanceMeters = 10.0;
  static const _maximumSamples = 5000;

  Timer? _timer;
  StreamSubscription<Position>? _subscription;
  final GeofenceGate _gate = GeofenceGate();
  bool _finishing = false;
  LatLng? _lastTrackedPoint;

  @override
  RacerState build() {
    ref.onDispose(() {
      _timer?.cancel();
      unawaited(_subscription?.cancel());
    });
    return const RacerState();
  }

  void selectTrack(LatLng center, {String? name}) {
    if (state.phase == RacerPhase.armed ||
        state.phase == RacerPhase.racing ||
        state.phase == RacerPhase.finishing) {
      return;
    }
    state = state.copyWith(
      phase: RacerPhase.setup,
      trackCenter: center,
      trackName: name ?? 'Custom track',
      clearError: true,
      clearResult: true,
      clearPersonalBest: true,
      elapsed: Duration.zero,
      distanceMeters: 0,
      topSpeedKmh: 0,
      samples: const [],
    );
  }

  void setRadius(double radius) {
    if (state.phase == RacerPhase.armed ||
        state.phase == RacerPhase.racing ||
        state.phase == RacerPhase.finishing) {
      return;
    }
    state = state.copyWith(radiusMeters: radius.clamp(50, 200));
  }

  Future<void> arm() async {
    if (state.phase == RacerPhase.armed ||
        state.phase == RacerPhase.racing ||
        state.phase == RacerPhase.finishing) {
      return;
    }
    try {
      await _ensureLocationAccess();
      await _subscription?.cancel();
      _gate.reset();
      _lastTrackedPoint = null;
      state = state.copyWith(
        phase: RacerPhase.armed,
        elapsed: Duration.zero,
        distanceMeters: 0,
        topSpeedKmh: 0,
        samples: const [],
        clearResult: true,
        clearPersonalBest: true,
        clearError: true,
      );
      _subscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.bestForNavigation,
              distanceFilter: 2,
            ),
          ).listen(
            _onPosition,
            onError: (Object error) {
              state = state.copyWith(error: 'GPS error: $error');
            },
          );
    } catch (error) {
      state = state.copyWith(error: error.toString());
    }
  }

  Future<void> cancel() async {
    if (state.phase == RacerPhase.finishing) return;
    _timer?.cancel();
    _timer = null;
    await _subscription?.cancel();
    _subscription = null;
    _gate.reset();
    _lastTrackedPoint = null;
    state = state.copyWith(
      phase: RacerPhase.setup,
      elapsed: Duration.zero,
      distanceMeters: 0,
      topSpeedKmh: 0,
      samples: const [],
      clearError: true,
    );
  }

  Future<void> interruptForBackground() async {
    if (state.phase != RacerPhase.armed && state.phase != RacerPhase.racing) {
      return;
    }
    await cancel();
    state = state.copyWith(
      error: 'Racer stopped because the app left the foreground.',
    );
  }

  void _onPosition(Position position) {
    if (position.accuracy > _maxAccuracyMeters) return;
    if (DateTime.now().difference(position.timestamp).abs() >
        _maximumPositionAge) {
      return;
    }
    final point = LatLng(position.latitude, position.longitude);
    final distanceToCenter = Geolocator.distanceBetween(
      point.latitude,
      point.longitude,
      state.trackCenter.latitude,
      state.trackCenter.longitude,
    );

    if (state.phase == RacerPhase.armed) {
      state = state.copyWith(currentPosition: point);
      if (_gate.confirmEntry(
        distanceMeters: distanceToCenter,
        radiusMeters: state.radiusMeters,
        accuracyMeters: position.accuracy,
      )) {
        _startRace(position, point);
      }
      return;
    }
    if (state.phase != RacerPhase.racing) return;
    if (_gate.confirmExit(
      distanceMeters: distanceToCenter,
      radiusMeters: state.radiusMeters,
      accuracyMeters: position.accuracy,
    )) {
      unawaited(_finishRace());
      return;
    }

    final samples = [...state.samples];
    var distance = state.distanceMeters;
    if (_lastTrackedPoint != null) {
      final last = _lastTrackedPoint!;
      final step = Geolocator.distanceBetween(
        last.latitude,
        last.longitude,
        point.latitude,
        point.longitude,
      );
      if (step <= 100) distance += step;
    }
    _lastTrackedPoint = point;
    final speed = math.max(0.0, position.speed * 3.6);
    if (samples.length < _maximumSamples) {
      samples.add(
        SpeedSample(lat: point.latitude, lng: point.longitude, speedKmh: speed),
      );
    }
    state = state.copyWith(
      currentPosition: point,
      distanceMeters: distance,
      topSpeedKmh: math.max(state.topSpeedKmh, speed),
      samples: List.unmodifiable(samples),
    );
  }

  void _startRace(Position position, LatLng point) {
    final now = DateTime.now();
    final speed = math.max(0.0, position.speed * 3.6);
    _lastTrackedPoint = point;
    state = state.copyWith(
      phase: RacerPhase.racing,
      startedAt: now,
      currentPosition: point,
      topSpeedKmh: speed,
      samples: [
        SpeedSample(lat: point.latitude, lng: point.longitude, speedKmh: speed),
      ],
    );
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final startedAt = state.startedAt;
      if (state.phase == RacerPhase.racing && startedAt != null) {
        state = state.copyWith(elapsed: DateTime.now().difference(startedAt));
      }
    });
  }

  Future<void> _finishRace() async {
    if (_finishing ||
        state.phase != RacerPhase.racing ||
        state.startedAt == null) {
      return;
    }
    _finishing = true;
    final snapshot = state;
    state = state.copyWith(phase: RacerPhase.finishing);
    _timer?.cancel();
    _timer = null;
    await _subscription?.cancel();
    _subscription = null;
    final elapsed = DateTime.now().difference(snapshot.startedAt!);

    if (elapsed < _minimumRaceDuration ||
        snapshot.distanceMeters < _minimumRaceDistanceMeters) {
      state = state.copyWith(
        phase: RacerPhase.finished,
        elapsed: elapsed,
        error: 'Race ignored: record at least 10 m over 3 seconds.',
        clearResult: true,
      );
      _finishing = false;
      return;
    }

    final average =
        (snapshot.distanceMeters / 1000) /
        (elapsed.inMilliseconds / Duration.millisecondsPerHour);
    final trackId = _trackId(snapshot);
    final record = RunRecord(
      startedAt: snapshot.startedAt!,
      durationSeconds: elapsed.inSeconds,
      distanceMeters: snapshot.distanceMeters,
      topSpeedKmh: snapshot.topSpeedKmh,
      averageSpeedKmh: average,
      destinationName: 'Racer • ${snapshot.trackName}',
      samples: snapshot.samples,
      activityType: 'racer',
      trackId: trackId,
      trackCenterLat: snapshot.trackCenter.latitude,
      trackCenterLng: snapshot.trackCenter.longitude,
      trackRadiusMeters: snapshot.radiusMeters,
    );
    try {
      final saved = await ref.read(runRepositoryProvider).save(record);
      final all = await ref.read(runRepositoryProvider).getAll();
      final comparable = all.where(
        (run) =>
            run.activityType == 'racer' &&
            run.trackId == trackId &&
            run.clientTripId != saved.clientTripId &&
            run.durationSeconds > 0,
      );
      final best = comparable.isEmpty
          ? null
          : comparable.map((run) => run.durationSeconds).reduce(math.min);
      ref.invalidate(runHistoryProvider);
      ref.invalidate(drivingStatsProvider);
      ref.invalidate(territoriesProvider);
      state = state.copyWith(
        phase: RacerPhase.finished,
        elapsed: elapsed,
        result: saved,
        personalBestSeconds: best,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        phase: RacerPhase.finished,
        elapsed: elapsed,
        error: 'Could not preserve race result: $error',
      );
    } finally {
      _finishing = false;
    }
  }

  String _trackId(RacerState value) =>
      'zone:${value.trackCenter.latitude.toStringAsFixed(5)}:'
      '${value.trackCenter.longitude.toStringAsFixed(5)}:'
      '${value.radiusMeters.round()}';

  Future<void> _ensureLocationAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('Turn on Location Services to arm Racer.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError('Location permission is required for Racer.');
    }
  }
}
