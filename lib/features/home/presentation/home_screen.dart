import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/racing_theme.dart';
import '../../../features/run/application/run_providers.dart';
import '../../../features/run/presentation/active_run_screen.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/led_button.dart';
import '../../../shared/widgets/race_widgets.dart';
import 'route_stop.dart';

class _Destination {
  const _Destination(this.name, this.position);
  final String name;
  final LatLng position;
}

const _destinations = [
  _Destination('Avenue Habib Bourguiba, Tunis', LatLng(36.8065, 10.1815)),
  _Destination('Carthage Archaeological Site', LatLng(36.8588, 10.3301)),
  _Destination('Sidi Bou Said', LatLng(36.8706, 10.3416)),
  _Destination('Bardo National Museum', LatLng(36.8097, 10.1347)),
  _Destination('Hammamet Medina', LatLng(36.4004, 10.6167)),
];

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const _initialCenter = LatLng(36.8065, 10.1815);

  final _searchController = TextEditingController();
  final _mapController = MapController();
  _Destination? _selected;
  LatLng? _currentPosition;
  List<_Destination> _matches = const [];
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _centerOnCurrentPosition(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search(String query) {
    final normalized = query.trim().toLowerCase();
    setState(() {
      _matches = normalized.isEmpty
          ? const []
          : _destinations
                .where((d) => d.name.toLowerCase().contains(normalized))
                .toList();
    });
  }

  void _submit(String query) {
    if (_matches.isNotEmpty) {
      _selectDestination(_matches.first);
      return;
    }
    final parts = query
        .split(',')
        .map((part) => double.tryParse(part.trim()))
        .toList();
    if (parts.length == 2 && parts.every((value) => value != null)) {
      final lat = parts[0]!;
      final lng = parts[1]!;
      if (lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
        _selectDestination(
          _Destination(
            '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
            LatLng(lat, lng),
          ),
        );
        return;
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Try a listed Tunisia destination or enter latitude, longitude.',
        ),
      ),
    );
  }

  void _selectDestination(_Destination destination) {
    FocusScope.of(context).unfocus();
    _searchController.text = destination.name;
    setState(() {
      _selected = destination;
      _matches = const [];
    });
    _mapController.move(destination.position, 15);
    _showRoutePopup(destination);
  }

  Future<void> _centerOnCurrentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) return;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    if (!mounted) return;
    final point = LatLng(position.latitude, position.longitude);
    setState(() => _currentPosition = point);
    _mapController.move(point, 15);
  }

  void _showRoutePopup(_Destination destination) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 26),
          decoration: const BoxDecoration(
            color: AppColors.panel,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 46,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.muted,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'ROUTE READY',
                style: TextStyle(
                  color: AppColors.blue,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Start from your live GPS position',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 20),
              RouteStop(
                icon: Icons.my_location_rounded,
                label: 'FROM',
                value: _currentPosition == null
                    ? 'Current position will be acquired at start'
                    : 'Your current position',
              ),
              const Padding(
                padding: EdgeInsets.only(left: 17),
                child: SizedBox(
                  height: 20,
                  child: VerticalDivider(color: AppColors.blue, thickness: 2),
                ),
              ),
              RouteStop(
                icon: Icons.flag_rounded,
                label: 'TO',
                value: destination.name,
              ),
              const SizedBox(height: 24),
              LedButton(
                label: 'START FROM CURRENT POSITION',
                icon: Icons.navigation_rounded,
                busy: _starting,
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  _startRun(destination);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startRun(_Destination destination) async {
    setState(() => _starting = true);
    try {
      await ref
          .read(activeRunProvider.notifier)
          .start(
            destination: destination.position,
            destinationName: destination.name,
          );
      if (!mounted) return;
      await Navigator.of(
        context,
      ).push(tripLaunchRoute(const ActiveRunScreen()));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_messageFor(error))));
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _startFreeDrive() async {
    setState(() => _starting = true);
    try {
      await ref.read(activeRunProvider.notifier).start(freeDrive: true);
      if (!mounted) return;
      await Navigator.of(
        context,
      ).push(tripLaunchRoute(const ActiveRunScreen()));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_messageFor(error))));
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  String _messageFor(Object error) => error is StateError
      ? error.message.toString()
      : 'Could not start GPS tracking: $error';

  @override
  Widget build(BuildContext context) {
    final autoTrack = ref.watch(
      activeRunProvider.select((s) => s.autoTrackEnabled),
    );
    final autoStatus = ref.watch(
      activeRunProvider.select((s) => s.autoTrackStatus),
    );
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: _initialCenter,
              initialZoom: 12.5,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.d.racing.d',
              ),
              if (_selected != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selected!.position,
                      width: 52,
                      height: 52,
                      child: const Icon(
                        Icons.location_on_rounded,
                        color: AppColors.blue,
                        size: 48,
                      ),
                    ),
                  ],
                ),
              if (_currentPosition != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: _currentPosition!,
                      radius: 20,
                      color: AppColors.blue.withValues(alpha: .18),
                    ),
                    CircleMarker(
                      point: _currentPosition!,
                      radius: 10,
                      color: AppColors.blue,
                      borderColor: Colors.white,
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
            ],
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxHeight < 760;
                return Padding(
                  padding: EdgeInsets.fromLTRB(12, compact ? 10 : 16, 12, 12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: RaceColors.ink,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: RaceColors.neonBlue,
                                width: 2,
                              ),
                              boxShadow: [RaceColors.glow(RaceColors.neonBlue)],
                            ),
                            child: const Text(
                              'D',
                              style: TextStyle(
                                color: RaceColors.neonBlue,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: _search,
                              onSubmitted: _submit,
                              textInputAction: TextInputAction.search,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Search destination or lat, lng',
                                hintStyle: const TextStyle(
                                  color: RaceColors.muted,
                                ),
                                prefixIcon: const Icon(
                                  Icons.search,
                                  color: RaceColors.neonBlue,
                                ),
                                suffixIcon: IconButton(
                                  onPressed: () =>
                                      _submit(_searchController.text),
                                  icon: const Icon(
                                    Icons.arrow_forward_rounded,
                                    color: RaceColors.neonBlue,
                                  ),
                                ),
                                filled: true,
                                fillColor: RaceColors.panelSolid,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: BorderSide(
                                    color: RaceColors.neonBlue
                                        .withValues(alpha: .3),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_matches.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(left: 64, top: 6),
                          decoration: RaceColors.panelDeco(
                            border: RaceColors.neonBlue,
                            radius: 16,
                          ),
                          child: ListView.separated(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: _matches.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (_, index) {
                              final destination = _matches[index];
                              return ListTile(
                                leading: const Icon(
                                  Icons.flag_rounded,
                                  color: RaceColors.neonBlue,
                                ),
                                title: Text(destination.name),
                                onTap: () => _selectDestination(destination),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          PulseDot(
                            color: _currentPosition == null
                                ? RaceColors.amber
                                : RaceColors.lime,
                            label: _currentPosition == null
                                ? 'LOCATING GPS'
                                : 'GPS READY',
                          ),
                          const Spacer(),
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: RaceColors.panelSolid,
                              border: Border.all(
                                color: RaceColors.neonBlue.withValues(alpha: .4),
                              ),
                              boxShadow: [
                                RaceColors.glow(RaceColors.neonBlue, .35),
                              ],
                            ),
                            child: IconButton(
                              onPressed: _centerOnCurrentPosition,
                              icon: const Icon(
                                Icons.my_location_rounded,
                                color: RaceColors.neonBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      NeonPanel(
                        color: RaceColors.neonBlue,
                        radius: 28,
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: RaceColors.neonBlue
                                        .withValues(alpha: .16),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      RaceColors.glow(
                                        RaceColors.neonBlue,
                                        .4,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.directions_car_filled_rounded,
                                    color: RaceColors.neonBlue,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ShaderMask(
                                        shaderCallback: (r) =>
                                            RaceColors.heroGradient
                                                .createShader(r),
                                        child: const Text(
                                          'ENGINE READY',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.3,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
                                        'Record every road you take',
                                        style: TextStyle(
                                          color: RaceColors.muted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: RaceColors.ink,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: autoTrack
                                      ? RaceColors.neonBlue
                                          .withValues(alpha: .5)
                                      : Colors.white12,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    autoTrack
                                        ? Icons.sensors_rounded
                                        : Icons.sensors_off_rounded,
                                    color: autoTrack
                                        ? RaceColors.neonBlue
                                        : RaceColors.muted,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      autoTrack
                                          ? 'AUTO-TRACKING ENABLED'
                                          : 'AUTO-TRACKING OFF',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1,
                                        color: autoTrack
                                            ? RaceColors.neonBlue
                                            : RaceColors.muted,
                                      ),
                                    ),
                                  ),
                                  Switch.adaptive(
                                    value: autoTrack,
                                    activeThumbColor: RaceColors.neonBlue,
                                    activeTrackColor: RaceColors.neonBlue
                                        .withValues(alpha: .4),
                                    onChanged: (v) => ref
                                        .read(activeRunProvider.notifier)
                                        .setAutoTrackEnabled(v),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              autoStatus,
                              style: const TextStyle(
                                color: RaceColors.muted,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 14),
                            RaceButton(
                              label: 'START FREE DRIVE',
                              busy: _starting,
                              onPressed: _startFreeDrive,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Search above to set a destination, or start a free drive from your live GPS.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

