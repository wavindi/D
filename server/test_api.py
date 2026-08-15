import os
import sqlite3
import tempfile
from pathlib import Path
from uuid import uuid4

import pytest

_tmp = tempfile.TemporaryDirectory()
os.environ["D_DB_PATH"] = str(Path(_tmp.name) / "test.db")
os.environ["D_JWT_SECRET"] = "test-secret-that-is-long-enough-for-tests"

import server as server_module
from fastapi.testclient import TestClient
from server import app

client = TestClient(app)


@pytest.fixture(autouse=True)
def _clear_rate_limits():
    with server_module._RATE_LOCK:
        server_module._RATE_BUCKETS.clear()
    yield
    with server_module._RATE_LOCK:
        server_module._RATE_BUCKETS.clear()


def _signup(email: str, password: str = "strong-secret-12") -> tuple[str, dict]:
    response = client.post(
        "/api/signup",
        json={"name": "Mobile Driver", "email": email, "password": password},
    )
    assert response.status_code == 200, response.text
    return response.json()["token"], response.json()["user"]


def _trip_payload(**overrides):
    value = {
        "client_trip_id": str(uuid4()),
        "started_at": "2026-08-12T20:00:00Z",
        "duration_seconds": 120,
        "distance_meters": 1500,
        "top_speed_kmh": 80,
        "average_speed_kmh": 45,
        "destination_name": "From current location",
        "stopped_seconds": 4,
        "samples": [{"lat": 36.8, "lng": 10.18, "speed_kmh": 45}],
        "activity_type": "drive",
    }
    value.update(overrides)
    return value


def test_signup_login_and_idempotent_trip_roundtrip():
    token, _ = _signup("roundtrip@example.com")
    headers = {"Authorization": f"Bearer {token}"}

    me = client.get("/api/me", headers=headers)
    assert me.status_code == 200
    assert me.json()["name"] == "Mobile Driver"

    payload = _trip_payload()
    first = client.post("/api/trips", headers=headers, json=payload)
    duplicate = client.post("/api/trips", headers=headers, json=payload)
    assert first.status_code == duplicate.status_code == 200
    assert first.json()["id"] == duplicate.json()["id"]
    assert first.json()["deduplicated"] is False
    assert duplicate.json()["deduplicated"] is True

    trips = client.get("/api/trips", headers=headers)
    assert trips.status_code == 200
    assert len(trips.json()["trips"]) == 1
    assert trips.json()["trips"][0]["client_trip_id"] == payload["client_trip_id"]

    trip_id = first.json()["id"]
    deleted = client.delete(f"/api/trips/{trip_id}", headers=headers)
    assert deleted.status_code == 200
    assert client.delete(f"/api/trips/{trip_id}", headers=headers).status_code == 404
    assert client.get("/api/trips", headers=headers).json()["trips"] == []

    login = client.post(
        "/api/login",
        json={"email": "roundtrip@example.com", "password": "strong-secret-12"},
    )
    assert login.status_code == 200
    login_token = login.json()["token"]
    login_headers = {"Authorization": f"Bearer {login_token}"}
    assert client.post("/api/logout", headers=login_headers).status_code == 200
    assert client.get("/api/me", headers=login_headers).status_code == 401


@pytest.mark.parametrize(
    "changes",
    [
        {"started_at": "not-a-date"},
        {"duration_seconds": -1},
        {"distance_meters": -1},
        {"top_speed_kmh": 601},
        {"stopped_seconds": 121},
        {"samples": [{"lat": 91, "lng": 10, "speed_kmh": 20}]},
        {"samples": [{"lat": 36, "lng": 181, "speed_kmh": 20}]},
        {"activity_type": "racer", "track_id": None},
    ],
)
def test_invalid_trip_payloads_are_rejected(changes):
    token, _ = _signup(f"validation-{uuid4()}@example.com")
    response = client.post(
        "/api/trips",
        headers={"Authorization": f"Bearer {token}"},
        json=_trip_payload(**changes),
    )
    assert response.status_code == 422


def test_trip_delete_is_scoped_to_owner():
    owner_token, _ = _signup("owner@example.com")
    other_token, _ = _signup("other@example.com")
    created = client.post(
        "/api/trips",
        headers={"Authorization": f"Bearer {owner_token}"},
        json=_trip_payload(),
    )
    trip_id = created.json()["id"]
    denied = client.delete(
        f"/api/trips/{trip_id}",
        headers={"Authorization": f"Bearer {other_token}"},
    )
    assert denied.status_code == 404
    owner_trips = client.get(
        "/api/trips", headers={"Authorization": f"Bearer {owner_token}"}
    ).json()["trips"]
    assert [trip["id"] for trip in owner_trips] == [trip_id]


def test_login_is_rate_limited_after_repeated_failures():
    email = "rate-limit@example.com"
    _signup(email)
    statuses = [
        client.post("/api/login", json={"email": email, "password": "wrong"}).status_code
        for _ in range(10)
    ]
    assert statuses == [401] * 10
    blocked = client.post(
        "/api/login", json={"email": email, "password": "strong-secret-12"}
    )
    assert blocked.status_code == 429
    assert "Retry-After" in blocked.headers


def test_legacy_trip_schema_is_migrated(monkeypatch, tmp_path):
    legacy_db = tmp_path / "legacy.db"
    connection = sqlite3.connect(legacy_db)
    connection.executescript(
        """
        CREATE TABLE users (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          email TEXT NOT NULL UNIQUE,
          name TEXT NOT NULL,
          password_hash TEXT NOT NULL,
          created_at TEXT NOT NULL
        );
        CREATE TABLE trips (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL,
          started_at TEXT NOT NULL,
          duration_seconds INTEGER NOT NULL,
          distance_meters REAL NOT NULL,
          top_speed_kmh REAL NOT NULL,
          average_speed_kmh REAL NOT NULL,
          destination_name TEXT,
          stopped_seconds INTEGER NOT NULL DEFAULT 0,
          samples_json TEXT NOT NULL DEFAULT '[]',
          created_at TEXT NOT NULL
        );
        """
    )
    connection.close()

    monkeypatch.setattr(server_module, "DB_PATH", legacy_db)
    server_module.init_db()
    connection = sqlite3.connect(legacy_db)
    columns = {row[1] for row in connection.execute("PRAGMA table_info(trips)")}
    user_columns = {row[1] for row in connection.execute("PRAGMA table_info(users)")}
    indexes = {row[1] for row in connection.execute("PRAGMA index_list(trips)")}
    connection.close()

    assert {
        "client_trip_id",
        "activity_type",
        "track_id",
        "track_center_lat",
        "track_center_lng",
        "track_radius_meters",
    } <= columns
    assert "idx_trips_user_client" in indexes
    assert "token_version" in user_columns
