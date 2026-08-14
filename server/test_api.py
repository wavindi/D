import os
import tempfile
from pathlib import Path

_tmp = tempfile.TemporaryDirectory()
os.environ["D_DB_PATH"] = str(Path(_tmp.name) / "test.db")
os.environ["D_JWT_SECRET"] = "test-secret-that-is-long-enough-for-tests"

from fastapi.testclient import TestClient
from server import app

client = TestClient(app)


def test_signup_login_and_trip_roundtrip():
    signup = client.post(
        "/api/signup",
        json={"name": "Mobile Driver", "email": "driver@example.com", "password": "secret12"},
    )
    assert signup.status_code == 200
    token = signup.json()["token"]
    headers = {"Authorization": f"Bearer {token}"}

    me = client.get("/api/me", headers=headers)
    assert me.status_code == 200
    assert me.json()["name"] == "Mobile Driver"

    trip = client.post(
        "/api/trips",
        headers=headers,
        json={
            "started_at": "2026-08-12T20:00:00Z",
            "duration_seconds": 120,
            "distance_meters": 1500,
            "top_speed_kmh": 80,
            "average_speed_kmh": 45,
            "destination_name": "From current location",
            "stopped_seconds": 4,
            "samples": [{"lat": 36.8, "lng": 10.18, "speed_kmh": 45}],
        },
    )
    assert trip.status_code == 200
    trip_id = trip.json()["id"]

    trips = client.get("/api/trips", headers=headers)
    assert trips.status_code == 200
    assert len(trips.json()["trips"]) == 1
    assert trips.json()["trips"][0]["top_speed_kmh"] == 80

    deleted = client.delete(f"/api/trips/{trip_id}", headers=headers)
    assert deleted.status_code == 200
    assert client.get("/api/trips", headers=headers).json()["trips"] == []

    login = client.post(
        "/api/login",
        json={"email": "driver@example.com", "password": "secret12"},
    )
    assert login.status_code == 200
