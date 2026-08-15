#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="${REPO_DIR:-/home/dali/user-files/github-repos/D}"
APP_ROOT="${APP_ROOT:-/home/dali/user-files/test-site}"
API_ROOT="${API_ROOT:-/home/dali/user-files/d-api}"

FLUTTER_ROOT="${FLUTTER_ROOT:-/home/dali/flutter-3.47}"
export PATH="$FLUTTER_ROOT/bin:$PATH"
cd "$REPO_DIR"
flutter pub get --enforce-lockfile
flutter analyze
flutter test
flutter build web --release --base-href /

rm -rf "$APP_ROOT"
mkdir -p "$APP_ROOT"
cp -a build/web/. "$APP_ROOT"/
find "$APP_ROOT" -type d -exec chmod 755 {} \;
find "$APP_ROOT" -type f -exec chmod 644 {} \;

mkdir -p "$API_ROOT/data"
if [[ -f "$API_ROOT/data/d.db" ]]; then
  cp -p "$API_ROOT/data/d.db" "$API_ROOT/data/d.db.backup-$(date -u +%Y%m%dT%H%M%SZ)"
fi
python3 -m venv "$API_ROOT/.venv"
"$API_ROOT/.venv/bin/pip" install -r server/requirements.txt
cp server/server.py "$API_ROOT/server.py"

if [[ ! -f "$API_ROOT/.env" ]]; then
  SECRET=$(python3 -c 'import secrets; print(secrets.token_urlsafe(48))')
  printf 'D_JWT_SECRET=%s\nD_DB_PATH=%s/data/d.db\n' "$SECRET" "$API_ROOT" > "$API_ROOT/.env"
  chmod 600 "$API_ROOT/.env"
fi

mkdir -p "$HOME/.config/systemd/user"
cp deploy/d-api.service "$HOME/.config/systemd/user/d-api.service"
systemctl --user daemon-reload
systemctl --user enable d-api.service
systemctl --user restart d-api.service

for _ in {1..20}; do
  if curl --fail --silent --show-error http://127.0.0.1:8911/api/health >/dev/null; then
    break
  fi
  sleep 1
done
curl --fail --silent --show-error http://127.0.0.1:8911/api/health >/dev/null
python3 - <<'PY'
import json
import urllib.request

schema = json.load(urllib.request.urlopen("http://127.0.0.1:8911/openapi.json", timeout=10))
methods = schema.get("paths", {}).get("/api/trips/{trip_id}", {})
if "delete" not in methods:
    raise SystemExit("Deployed API is missing DELETE /api/trips/{trip_id}")
PY

echo "Built mobile web assets: $APP_ROOT"
echo "API health: http://127.0.0.1:8911/api/health"
echo "Install deploy/Caddyfile.example in Caddy for permanent public routing."
