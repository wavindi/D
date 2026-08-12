import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import '../../../data/database/app_database.dart';
import '../../../data/repositories/run_repository.dart';
import '../../../domain/models/run_record.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) => AppDatabase());
final runRepositoryProvider = Provider<RunRepository>(
  (ref) => RunRepository(ref.watch(appDatabaseProvider)),
);
final runHistoryProvider = FutureProvider<List<RunRecord>>(
  (ref) => ref.watch(runRepositoryProvider).getAll(),
);

class RunState {
  const RunState({
    this.isActive = false,
    this.elapsed = Duration.zero,
    this.currentSpeedKmh = 0,
    this.maxSpeedKmh = 0,
    this.distanceMeters = 0,
    this.route = const [],
    this.startedAt,
    this.destination,
    this.destinationName,
  });

  final bool isActive;
  final Duration elapsed;
  final double currentSpeedKmh;
  final double maxSpeedKmh;
  final double distanceMeters;
  final List<LatLng> route;
  final DateTime? startedAt;
  final LatLng? destination;
  final String? destinationName;

  RunState copyWith({
    bool? isActive,
    Duration? elapsed,
    double? currentSpeedKmh,
    double? maxSpeedKmh,
    double? distanceMeters,
    List<LatLng>? route,
    DateTime? startedAt,
    LatLng? destination,
    String? destinationName,
  }) => RunState(
    isActive: isActive ?? this.isActive,
    elapsed: elapsed ?? this.elapsed,
    currentSpeedKmh: currentSpeedKmh ?? this.currentSpeedKmh,
    maxSpeedKmh: maxSpeedKmh ?? this.maxSpeedKmh,
    distanceMeters: distanceMeters ?? this.distanceMeters,
    route: route ?? this.route,
    startedAt: startedAt ?? this.startedAt,
    destination: destination ?? this.destination,
    destinationName: destinationName ?? this.destinationName,
  );
}

final activeRunProvider = NotifierProvider<ActiveRunController, RunState>(
  ActiveRunController.new,
);

class ActiveRunController extends Notifier<RunState> {
  Timer? _timer;
  StreamSubscription<Position>? _positionSubscription;

  @override
  RunState build() {
    ref.onDispose(_stopTracking);
    return const RunState();
  }

  Future<void> start({
    required LatLng destination,
    required String destinationName,
  }) async {
    if (state.isActive) return;
    await _ensureLocationAccess();
    final initial = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
    );
    final startedAt = DateTime.now();
    state = RunState(
      isActive: true,
      startedAt: startedAt,
      route: [LatLng(initial.latitude, initial.longitude)],
      destination: destination,
      destinationName: destinationName,
    );
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.isActive) {
        state = state.copyWith(elapsed: DateTime.now().difference(startedAt));
      }
    });
    const settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 3,
    );
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(_onPosition);
  }

  void _onPosition(Position position) {
    if (!state.isActive) return;
    final point = LatLng(position.latitude, position.longitude);
    final route = [...state.route];
    var distance = state.distanceMeters;
    if (route.isNotEmpty) {
      final previous = route.last;
      distance += Geolocator.distanceBetween(
        previous.latitude,
        previous.longitude,
        point.latitude,
        point.longitude,
      );
    }
    route.add(point);
    final speed = math.max(0.0, position.speed * 3.6);
    state = state.copyWith(
      currentSpeedKmh: speed,
      maxSpeedKmh: math.max(state.maxSpeedKmh, speed),
      distanceMeters: distance,
      route: List.unmodifiable(route),
    );
  }

  Future<RunRecord> finish() async {
    if (!state.isActive || state.startedAt == null) {
      throw StateError('There is no active run.');
    }
    final finalState = state.copyWith(
      isActive: false,
      currentSpeedKmh: 0,
      elapsed: DateTime.now().difference(state.startedAt!),
    );
    state = finalState;
    await _stopTracking();
    final run = RunRecord(
      startedAt: finalState.startedAt!,
      durationSeconds: finalState.elapsed.inSeconds,
      distanceMeters: finalState.distanceMeters,
      topSpeedKmh: finalState.maxSpeedKmh,
    );
    final saved = await ref.read(runRepositoryProvider).save(run);
    ref.invalidate(runHistoryProvider);
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
