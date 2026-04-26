from __future__ import annotations

import json
import logging
import sqlite3
from datetime import datetime, timezone
from pathlib import Path

from ..scraper.live_scraper import LiveScraperError, fetch_all_live_opportunities

logger = logging.getLogger(__name__)

_base_dir = Path(__file__).resolve().parents[1]
_db_dir = _base_dir / "data"
_db_path = _db_dir / "opportunities.db"

_CACHE_KEY = "live_opportunities_v1"


def init_opportunities_db() -> None:
    _db_dir.mkdir(parents=True, exist_ok=True)
    with _get_connection() as connection:
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS cache (
                key TEXT PRIMARY KEY,
                payload TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
            """
        )
        connection.commit()


def get_cached_live_opportunities() -> tuple[list[dict], str] | None:
    with _get_connection() as connection:
        row = connection.execute(
            "SELECT payload, updated_at FROM cache WHERE key = ?",
            (_CACHE_KEY,),
        ).fetchone()
    if row is None:
        return None
    try:
        payload = json.loads(str(row["payload"]))
    except json.JSONDecodeError:
        return None
    if not isinstance(payload, list):
        return None
    return payload, str(row["updated_at"])


def store_cached_live_opportunities(opportunities: list[dict], *, updated_at: str) -> None:
    payload = json.dumps(opportunities, ensure_ascii=False)
    with _get_connection() as connection:
        connection.execute(
            """
            INSERT INTO cache (key, payload, updated_at)
            VALUES (?, ?, ?)
            ON CONFLICT(key) DO UPDATE SET
                payload = excluded.payload,
                updated_at = excluded.updated_at
            """,
            (_CACHE_KEY, payload, updated_at),
        )
        connection.commit()


def refresh_live_opportunities_cache() -> tuple[list[dict], str]:
    """
    Refresh and persist the merged opportunities list.

    Important: this is intentionally synchronous (scraping uses requests).
    Run it in a background worker/thread to avoid blocking request handling.
    """
    updated_at = datetime.now(timezone.utc).isoformat()

    try:
        live_records = fetch_all_live_opportunities()
        logger.info("Live scraper returned %d opportunities", len(live_records))
    except (LiveScraperError, Exception) as exc:  # noqa: BLE001
        logger.warning("Live scraper failed during refresh: %s", exc)
        live_records = []

    static_records: list[dict] = []
    json_path = _base_dir / "opportunities.json"
    if json_path.exists():
        try:
            raw = json.loads(json_path.read_text(encoding="utf-8"))
            if isinstance(raw, list):
                static_records = [r for r in raw if isinstance(r, dict)]
        except (json.JSONDecodeError, OSError) as exc:
            logger.warning("Could not load static opportunities.json: %s", exc)

    all_records = live_records + static_records
    seen_titles: set[str] = set()
    unique_records: list[dict] = []
    next_id = 1

    for record in all_records:
        title_key = str(record.get("title", "")).strip().lower()
        if not title_key or title_key in seen_titles:
            continue
        seen_titles.add(title_key)
        normalized = dict(record)
        normalized["id"] = next_id
        next_id += 1
        unique_records.append(normalized)

    store_cached_live_opportunities(unique_records, updated_at=updated_at)
    return unique_records, updated_at


def _get_connection() -> sqlite3.Connection:
    connection = sqlite3.connect(_db_path)
    connection.row_factory = sqlite3.Row
    return connection
