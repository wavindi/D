#!/usr/bin/env python3
"""Create a consistent private SQLite backup in the VPS realdata folder."""
from __future__ import annotations

import argparse
import hashlib
import os
import sqlite3
from datetime import datetime, timezone
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--source",
        default="/home/dali/user-files/d-api/data/d.db",
        help="Live SQLite database",
    )
    parser.add_argument(
        "--destination",
        default="/home/dali/user-files/d-api/realdata",
        help="Private backup directory",
    )
    parser.add_argument("--label", default="manual")
    args = parser.parse_args()

    source = Path(args.source).resolve()
    destination = Path(args.destination).resolve()
    if not source.is_file():
        raise SystemExit(f"Database not found: {source}")

    destination.mkdir(parents=True, exist_ok=True)
    destination.chmod(0o700)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    output = destination / f"d-{args.label}-{stamp}.db"

    with sqlite3.connect(source) as live, sqlite3.connect(output) as backup:
        live.backup(backup)
        integrity = backup.execute("PRAGMA integrity_check").fetchone()[0]
        users = backup.execute("SELECT COUNT(*) FROM users").fetchone()[0]
        trips = backup.execute("SELECT COUNT(*) FROM trips").fetchone()[0]

    if integrity != "ok":
        output.unlink(missing_ok=True)
        raise SystemExit(f"Backup integrity failed: {integrity}")

    output.chmod(0o600)
    latest = destination / "latest.db"
    latest.unlink(missing_ok=True)
    latest.symlink_to(output.name)
    digest = hashlib.sha256(output.read_bytes()).hexdigest()
    print(f"backup={output}")
    print(f"integrity={integrity}")
    print(f"users={users}")
    print(f"trips={trips}")
    print(f"sha256={digest}")


if __name__ == "__main__":
    main()
