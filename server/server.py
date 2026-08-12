#!/usr/bin/env python3
"""D Drive Tracker API: signup, login, user trips. SQLite on this VPS."""
from __future__ import annotations

import json
import os
import re
import sqlite3
import time
from contextlib import contextmanager
from datetime import datetime, timedelta, timezone
from pathlib import Path

import bcrypt
import jwt
from fastapi import Depends, FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

ROOT = Path(__file__).resolve().parent
ENV_PATH = ROOT / ".env"
if ENV_PATH.exists():
    for line in ENV_PATH.read_text().splitlines():
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip())

DB_PATH = Path(os.environ.get("D_DB_PATH", str(ROOT / "data" / "d.db")))
JWT_SECRET = os.environ.get("D_JWT_SECRET") or "change-me"
JWT_ALG = "HS256"
TOKEN_DAYS = 30

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


init_db()


class SignupIn(BaseModel):
    name: str = Field(min_length=2, max_length=80)
    email: str = Field(min_length=5, max_length=160)
    password: str = Field(min_length=6, max_length=128)


class LoginIn(BaseModel):
    email: str
    password: str


class TripIn(BaseModel):
    started_at: str
    duration_seconds: int
    distance_meters: float
    top_speed_kmh: float
    average_speed_kmh: float = 0
    destination_name: str | None = None
    stopped_seconds: int = 0
    samples: list[dict] = Field(default_factory=list)


def _token(user_id: int, email: str) -> str:
    now = datetime.now(timezone.utc)
    payload = {
        "sub": str(user_id),
        "email": email,
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
        row = conn.execute("SELECT id, email, name FROM users WHERE id = ?", (user_id,)).fetchone()
    if row is None:
        raise HTTPException(status_code=401, detail="Account not found")
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
def signup(body: SignupIn):
    email = body.email.strip().lower()
    name = " ".join(body.name.split())
    if not EMAIL_RE.match(email):
        raise HTTPException(status_code=400, detail="Enter a valid email")
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
def login(body: LoginIn):
    email = body.email.strip().lower()
    with db() as conn:
        row = conn.execute(
            "SELECT id, email, name, password_hash FROM users WHERE email = ?",
            (email,),
        ).fetchone()
    if row is None or not bcrypt.checkpw(body.password.encode(), row["password_hash"].encode()):
        raise HTTPException(status_code=401, detail="Wrong email or password")
    return _user_payload(row, _token(row["id"], row["email"]))


@app.get("/api/me")
def me(user=Depends(current_user)):
    return user


@app.get("/api/trips")
def list_trips(user=Depends(current_user)):
    with db() as conn:
        rows = conn.execute(
            """
            SELECT id, started_at, duration_seconds, distance_meters, top_speed_kmh,
                   average_speed_kmh, destination_name, stopped_seconds, samples_json
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
            }
        )
    return {"trips": trips}


@app.post("/api/trips")
def create_trip(body: TripIn, user=Depends(current_user)):
    created = datetime.now(timezone.utc).isoformat()
    samples_json = json.dumps(body.samples)
    with db() as conn:
        cur = conn.execute(
            """
            INSERT INTO trips(
              user_id, started_at, duration_seconds, distance_meters, top_speed_kmh,
              average_speed_kmh, destination_name, stopped_seconds, samples_json, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                user["id"],
                body.started_at,
                body.duration_seconds,
                body.distance_meters,
                body.top_speed_kmh,
                body.average_speed_kmh,
                body.destination_name,
                body.stopped_seconds,
                samples_json,
                created,
            ),
        )
        trip_id = cur.lastrowid
    return {"id": trip_id, "ok": True}

