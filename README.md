# D

**D** is a GPS run tracker for car-racing enthusiasts. It pairs a black-and-electric-blue LED interface with live speed, distance, route tracking, and local run history.

## Features

- OpenStreetMap map tiles with no Google Maps API key or billing account
- Starts in Tunis, Tunisia and recentres on the driver's live GPS location when permission is granted
- Destination search with Tunisia presets or direct `latitude, longitude` coordinates
- Route-ready confirmation sheet showing the current-position start and selected destination
- Live active-run HUD for speed, elapsed time, maximum speed, and GPS route polyline
- SQLite-backed run history with a post-run scoreboard

## Technology

- Flutter with null safety
- Riverpod for state management
- `flutter_map` and OpenStreetMap tiles
- `geolocator` for device GPS, speed, and distance calculations
- `sqflite` for local run history

## Run the app

```bash
flutter pub get
flutter run
```

For a browser build:

```bash
flutter build web --release --no-wasm-dry-run
```

Use a physical device for meaningful GPS speed and distance data. Android and iOS location permission boilerplate is already configured.

## Map usage

D uses standard OpenStreetMap tiles, so it needs no key or billing account. The public tile service is appropriate for development and low-volume personal use. Use a compliant hosted OpenStreetMap tile provider before high-volume public production use.

## Project structure

```text
lib/
├── app.dart
├── main.dart
├── core/
│   ├── theme/app_theme.dart
│   └── utils/formatters.dart
├── data/
│   ├── database/app_database.dart
│   └── repositories/run_repository.dart
├── domain/models/run_record.dart
├── features/
│   ├── history/presentation/run_history_screen.dart
│   ├── home/presentation/
│   │   ├── home_screen.dart
│   │   └── route_stop.dart
│   └── run/
│       ├── application/run_providers.dart
│       └── presentation/
│           ├── active_run_screen.dart
│           └── scoreboard_screen.dart
└── shared/widgets/led_button.dart
```
