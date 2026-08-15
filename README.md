# D Drive Tracker

**D** is a mobile-first Flutter GPS drive tracker for web, Android, and iOS. It starts at the driver's live location, traces the driven road, colors route segments by speed, and records current speed, maximum speed, average speed, distance, elapsed time, and stopped time.

Live web app: **https://test.wajdi.site/**

## Features

- Mobile-first layout tested for iPhone 13 Pro Max and Samsung S25 FE sizes
- Signup and login with JWT sessions
- FastAPI + SQLite VPS database for accounts and authenticated trips
- Slide-out sidebar: Drive, Stats, Territory, Ranks, Trips, logout
- Animated page changes and run transitions
- START TRIP from the current GPS position
- Live map and speed-colored route trace
- Live current/max/average speed, distance, and timer
- Pause/resume and trip completion scoreboard
- Local cache for offline resilience; VPS is canonical when signed in
- Monthly statistics, territory cells, history, and leaderboard UI
- OpenStreetMap tiles with no Google Maps API key
- PWA/mobile viewport and iOS safe-area support

## Architecture

```text
lib/
├── data/api/d_api.dart                   # VPS auth/trips client
├── data/repositories/run_repository.dart # VPS-backed trips + local cache
├── features/auth/                        # AuthGate, login/signup
├── features/home/                        # Drive map and START TRIP
├── features/run/                         # GPS state, live HUD, scoreboard
├── features/stats/                       # Analytics
├── features/territory/                   # Claimed map cells
├── features/leaderboard/                 # Ranking UI
└── shared/widgets/app_shell.dart          # Sidebar and transitions
server/
├── server.py                             # FastAPI + SQLite API
├── requirements.txt
└── .env.example
deploy/
├── d-api.service                         # User systemd service
├── Caddyfile.example                     # Same-host /api reverse proxy
└── install-vps.sh                        # Reproducible VPS build/deploy
```

## Local Flutter development

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

The verified toolchain is Flutter `3.47.0` / Dart `3.13.0`. CI and the VPS
deployment use the committed `pubspec.lock`; use the same Flutter release when
changing dependencies.

Override the API endpoint at build time when targeting a non-default server:

```bash
flutter run --dart-define=D_API_BASE_URL=https://your-api.example
```

## V1 data reliability

- Completed trips are written to a user-scoped local outbox before networking.
- Pending creates and deletes retry when history refreshes.
- Client-generated UUIDs make trip uploads idempotent.
- Authentication tokens are stored with `flutter_secure_storage` and migrated
  away from legacy preferences.
- Racer uses confirmed outside-to-inside and inside-to-outside transitions with
  GPS hysteresis. Racer is intentionally foreground-only and stops if the app
  is backgrounded.
- Racer results carry stable track metadata and do not inflate normal driving
  statistics.

Web build:

```bash
flutter build web --release --base-href /
```

Browser geolocation requires HTTPS (or localhost). Allow location when prompted.

## Run the API locally

```bash
cd server
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
cp .env.example .env
# Replace D_JWT_SECRET with a strong random secret.
.venv/bin/uvicorn server:app --host 127.0.0.1 --port 8911
```

Endpoints:

- `GET /api/health`
- `POST /api/signup`
- `POST /api/login`
- `GET /api/me`
- `GET /api/trips`
- `POST /api/trips`

Passwords are bcrypt-hashed. JWT secrets and SQLite files are excluded from Git.

## VPS deployment

```bash
chmod +x deploy/install-vps.sh
./deploy/install-vps.sh
```

Then install the site block from `deploy/Caddyfile.example`, validate Caddy, and reload it. `/api*` must be reverse-proxied before the Flutter `file_server` handler.

Current production layout:

- Flutter web: `/home/dali/user-files/test-site`
- API: `/home/dali/user-files/d-api`
- SQLite: `/home/dali/user-files/d-api/data/d.db`
- Private real-data backups: `/home/dali/user-files/d-api/realdata`
- API service: `systemctl --user status d-api.service`

Create a consistent private backup without copying SQLite while it is being written:

```bash
python3 server/backup_realdata.py --label manual
```

The backup script verifies SQLite integrity, prints user/trip counts and a SHA-256 checksum, applies owner-only permissions, and updates `realdata/latest.db`. Real databases, password hashes, and user data are intentionally excluded from GitHub.

## Safety

Do not operate the phone while driving. Mount it securely and start/stop tracking only when parked or through a passenger.
