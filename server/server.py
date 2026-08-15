#!/usr/bin/env python3
"""D Drive Tracker API: signup, login, user trips. SQLite on this VPS."""
from __future__ import annotations

import json
import os
import re
import sqlite3
import threading
import time
from collections import defaultdict, deque
from contextlib import contextmanager
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Literal
from uuid import UUID

import bcrypt
import jwt
from fastapi import Depends, FastAPI, Header, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field, model_validator

ROOT = Path(__file__).resolve().parent
ENV_PATH = ROOT / ".env"
if ENV_PATH.exists():
    for line in ENV_PATH.read_text().splitlines():
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip())

DB_PATH = Path(os.environ.get("D_DB_PATH", str(ROOT / "data" / "d.db")))
JWT_SECRET = os.environ.get("D_JWT_SECRET", "")
if len(JWT_SECRET) < 32 or JWT_SECRET == "replace-with-a-long-random-secret":
    raise RuntimeError("Set D_JWT_SECRET to a random value of at least 32 characters")
JWT_ALG = "HS256"
TOKEN_DAYS = 30
MAX_TRIP_SAMPLES = 10_000

EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")

app = FastAPI(title="D Drive Tracker API")
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://test.wajdi.site",
        "http://localhost",
        "http://127.0.0.1",
    ],
    allow_origin_regex=r"https?://(localhost|127\.0\.0\.1|test\.wajdi\.site)(:\d+)?",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


def _connect() -> sqlite3.Connection:
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    conn.execute("PRAGMA journal_mode = WAL")
    conn.execute("PRAGMA busy_timeout = 5000")
    return conn


@contextmanager
def db():
    conn = _connect()
    try:
        yield conn
        conn.commit()
    finally:
        conn.close()


def init_db() -> None:
    with db() as conn:
        conn.executescript(
            """
            CREATE TABLE IF NOT EXISTS users (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              email TEXT NOT NULL UNIQUE,
              name TEXT NOT NULL,
              password_hash TEXT NOT NULL,
              created_at TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS trips (
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
              created_at TEXT NOT NULL,
              FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
            );
            CREATE INDEX IF NOT EXISTS idx_trips_user ON trips(user_id, started_at DESC);
            """
        )
        columns = {
            row["name"] for row in conn.execute("PRAGMA table_info(trips)").fetchall()
        }
        additions = {
            "client_trip_id": "TEXT",
            "activity_type": "TEXT NOT NULL DEFAULT 'drive'",
            "track_id": "TEXT",
            "track_center_lat": "REAL",
            "track_center_lng": "REAL",
            "track_radius_meters": "REAL",
        }
        for name, sql_type in additions.items():
            if name not in columns:
                conn.execute(f"ALTER TABLE trips ADD COLUMN {name} {sql_type}")
        conn.execute(
            """
            CREATE UNIQUE INDEX IF NOT EXISTS idx_trips_user_client
            ON trips(user_id, client_trip_id)
            WHERE client_trip_id IS NOT NULL
            """
        )
        user_columns = {
            row["name"] for row in conn.execute("PRAGMA table_info(users)").fetchall()
        }
        if "token_version" not in user_columns:
            conn.execute(
                "ALTER TABLE users ADD COLUMN token_version INTEGER NOT NULL DEFAULT 0"
            )


init_db()


class SignupIn(BaseModel):
    name: str = Field(min_length=2, max_length=80)
    email: str = Field(min_length=5, max_length=160)
    password: str = Field(min_length=10, max_length=128)


class LoginIn(BaseModel):
    email: str
    password: str


class SpeedSampleIn(BaseModel):
    lat: float = Field(ge=-90, le=90)
    lng: float = Field(ge=-180, le=180)
    speed_kmh: float = Field(ge=0, le=600)


class TripIn(BaseModel):
    client_trip_id: UUID | None = None
    started_at: datetime
    duration_seconds: int = Field(ge=0, le=604_800)
    distance_meters: float = Field(ge=0, le=10_000_000)
    top_speed_kmh: float = Field(ge=0, le=600)
    average_speed_kmh: float = Field(default=0, ge=0, le=600)
    destination_name: str | None = Field(default=None, max_length=200)
    stopped_seconds: int = Field(default=0, ge=0, le=604_800)
    samples: list[SpeedSampleIn] = Field(default_factory=list, max_length=MAX_TRIP_SAMPLES)
    activity_type: Literal["drive", "racer"] = "drive"
    track_id: str | None = Field(default=None, max_length=160)
    track_center_lat: float | None = Field(default=None, ge=-90, le=90)
    track_center_lng: float | None = Field(default=None, ge=-180, le=180)
    track_radius_meters: float | None = Field(default=None, ge=10, le=10_000)

    @model_validator(mode="after")
    def validate_consistency(self):
        if self.stopped_seconds > self.duration_seconds:
            raise ValueError("stopped_seconds cannot exceed duration_seconds")
        if self.activity_type == "racer" and not self.track_id:
            raise ValueError("track_id is required for racer results")
        return self


_RATE_LOCK = threading.Lock()
_RATE_BUCKETS: dict[tuple[str, str], deque[float]] = defaultdict(deque)


def _rate_key(request: Request, value: str = "") -> str:
    host = request.client.host if request.client else "unknown"
    return f"{host}:{value.strip().lower()}"


def _rate_check(scope: str, key: str, *, limit: int, window_seconds: int) -> None:
    now = time.monotonic()
    with _RATE_LOCK:
        bucket = _RATE_BUCKETS[(scope, key)]
        while bucket and now - bucket[0] >= window_seconds:
            bucket.popleft()
        if len(bucket) >= limit:
            retry_after = max(1, int(window_seconds - (now - bucket[0])))
            raise HTTPException(
                status_code=429,
                detail="Too many attempts. Try again later.",
                headers={"Retry-After": str(retry_after)},
            )


def _rate_record(scope: str, key: str) -> None:
    with _RATE_LOCK:
        _RATE_BUCKETS[(scope, key)].append(time.monotonic())


def _rate_clear(scope: str, key: str) -> None:
    with _RATE_LOCK:
        _RATE_BUCKETS.pop((scope, key), None)


def _token(user_id: int, email: str, token_version: int = 0) -> str:
    now = datetime.now(timezone.utc)
    payload = {
        "sub": str(user_id),
        "email": email,
        "ver": token_version,
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(days=TOKEN_DAYS)).timestamp()),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALG)


def current_user(authorization: str | None = Header(default=None)) -> dict:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Sign in required")
    token = authorization.split(" ", 1)[1].strip()
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALG])
    except jwt.PyJWTError:
        raise HTTPException(status_code=401, detail="Session expired. Sign in again.")
    user_id = int(payload.get("sub", 0))
    with db() as conn:
        row = conn.execute(
            "SELECT id, email, name, token_version FROM users WHERE id = ?",
            (user_id,),
        ).fetchone()
    if row is None:
        raise HTTPException(status_code=401, detail="Account not found")
    if int(payload.get("ver", 0)) != row["token_version"]:
        raise HTTPException(status_code=401, detail="Session expired. Sign in again.")
    return {"id": row["id"], "email": row["email"], "name": row["name"]}


def _user_payload(row, token: str) -> dict:
    return {
        "token": token,
        "user": {"id": row["id"], "email": row["email"], "name": row["name"]},
    }


@app.get("/api/health")
def health():
    return {"ok": True, "service": "d-api", "time": int(time.time())}


@app.post("/api/signup")
def signup(body: SignupIn, request: Request):
    rate_key = _rate_key(request)
    _rate_check("signup", rate_key, limit=5, window_seconds=3600)
    _rate_record("signup", rate_key)
    email = body.email.strip().lower()
    name = " ".join(body.name.split())
    if not EMAIL_RE.match(email):
        raise HTTPException(status_code=400, detail="Enter a valid email")
    if len(name) < 2:
        raise HTTPException(status_code=400, detail="Enter a valid name")
    password_hash = bcrypt.hashpw(body.password.encode(), bcrypt.gensalt()).decode()
    created = datetime.now(timezone.utc).isoformat()
    with db() as conn:
        existing = conn.execute("SELECT id FROM users WHERE email = ?", (email,)).fetchone()
        if existing:
            raise HTTPException(status_code=409, detail="This email already has an account")
        cur = conn.execute(
            "INSERT INTO users(email, name, password_hash, created_at) VALUES (?, ?, ?, ?)",
            (email, name, password_hash, created),
        )
        user_id = cur.lastrowid
        row = conn.execute("SELECT id, email, name FROM users WHERE id = ?", (user_id,)).fetchone()
    return _user_payload(row, _token(user_id, email))


@app.post("/api/login")
def login(body: LoginIn, request: Request):
    email = body.email.strip().lower()
    rate_key = _rate_key(request, email)
    _rate_check("login", rate_key, limit=10, window_seconds=300)
    with db() as conn:
        row = conn.execute(
            "SELECT id, email, name, password_hash, token_version FROM users WHERE email = ?",
            (email,),
        ).fetchone()
    if row is None or not bcrypt.checkpw(body.password.encode(), row["password_hash"].encode()):
        _rate_record("login", rate_key)
        raise HTTPException(status_code=401, detail="Wrong email or password")
    _rate_clear("login", rate_key)
    return _user_payload(
        row,
        _token(row["id"], row["email"], row["token_version"]),
    )


@app.get("/api/me")
def me(user=Depends(current_user)):
    return user


@app.post("/api/logout")
def logout(user=Depends(current_user)):
    with db() as conn:
        conn.execute(
            "UPDATE users SET token_version = token_version + 1 WHERE id = ?",
            (user["id"],),
        )
    return {"ok": True}


@app.get("/api/trips")
def list_trips(user=Depends(current_user)):
    with db() as conn:
        rows = conn.execute(
            """
            SELECT id, started_at, duration_seconds, distance_meters, top_speed_kmh,
                   average_speed_kmh, destination_name, stopped_seconds, samples_json,
                   client_trip_id, activity_type, track_id, track_center_lat,
                   track_center_lng, track_radius_meters
            FROM trips WHERE user_id = ? ORDER BY started_at DESC
            """,
            (user["id"],),
        ).fetchall()
    trips = []
    for row in rows:
        trips.append(
            {
                "id": row["id"],
                "started_at": row["started_at"],
                "duration_seconds": row["duration_seconds"],
                "distance_meters": row["distance_meters"],
                "top_speed_kmh": row["top_speed_kmh"],
                "average_speed_kmh": row["average_speed_kmh"],
                "destination_name": row["destination_name"],
                "stopped_seconds": row["stopped_seconds"],
                "samples": json.loads(row["samples_json"] or "[]"),
                "client_trip_id": row["client_trip_id"],
                "activity_type": row["activity_type"] or "drive",
                "track_id": row["track_id"],
                "track_center_lat": row["track_center_lat"],
                "track_center_lng": row["track_center_lng"],
                "track_radius_meters": row["track_radius_meters"],
            }
        )
    return {"trips": trips}


@app.post("/api/trips")
def create_trip(body: TripIn, user=Depends(current_user)):
    created = datetime.now(timezone.utc).isoformat()
    client_trip_id = str(body.client_trip_id) if body.client_trip_id else None
    started_value = body.started_at
    if started_value.tzinfo is None:
        started_value = started_value.replace(tzinfo=timezone.utc)
    started_at = started_value.astimezone(timezone.utc).isoformat()
    samples_json = json.dumps(
        [sample.model_dump() for sample in body.samples],
        separators=(",", ":"),
    )
    with db() as conn:
        if client_trip_id:
            existing = conn.execute(
                "SELECT id FROM trips WHERE user_id = ? AND client_trip_id = ?",
                (user["id"], client_trip_id),
            ).fetchone()
            if existing:
                return {"id": existing["id"], "ok": True, "deduplicated": True}
        try:
            cur = conn.execute(
                """
                INSERT INTO trips(
                  user_id, started_at, duration_seconds, distance_meters, top_speed_kmh,
                  average_speed_kmh, destination_name, stopped_seconds, samples_json,
                  created_at, client_trip_id, activity_type, track_id, track_center_lat,
                  track_center_lng, track_radius_meters
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    user["id"],
                    started_at,
                    body.duration_seconds,
                    body.distance_meters,
                    body.top_speed_kmh,
                    body.average_speed_kmh,
                    body.destination_name,
                    body.stopped_seconds,
                    samples_json,
                    created,
                    client_trip_id,
                    body.activity_type,
                    body.track_id,
                    body.track_center_lat,
                    body.track_center_lng,
                    body.track_radius_meters,
                ),
            )
            trip_id = cur.lastrowid
        except sqlite3.IntegrityError:
            if not client_trip_id:
                raise
            existing = conn.execute(
                "SELECT id FROM trips WHERE user_id = ? AND client_trip_id = ?",
                (user["id"], client_trip_id),
            ).fetchone()
            if not existing:
                raise
            trip_id = existing["id"]
            return {"id": trip_id, "ok": True, "deduplicated": True}
    return {"id": trip_id, "ok": True, "deduplicated": False}


@app.delete("/api/trips/{trip_id}")
def delete_trip(trip_id: int, user=Depends(current_user)):
    with db() as conn:
        cur = conn.execute(
            "DELETE FROM trips WHERE id = ? AND user_id = ?",
            (trip_id, user["id"]),
        )
        if cur.rowcount == 0:
            raise HTTPException(status_code=404, detail="Trip not found")
    return {"ok": True}

