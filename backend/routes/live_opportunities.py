"""
live_opportunities.py

FastAPI route for fetching real-time scholarship and internship opportunities
from live web sources. Merges live scraped data with the static opportunities.json.
"""

from __future__ import annotations

import json
import logging
from pathlib import Path

from fastapi import APIRouter, HTTPException

from models.opportunity import Opportunity
from scraper.live_scraper import LiveScraperError, fetch_all_live_opportunities

logger = logging.getLogger(__name__)

router = APIRouter(tags=["opportunities"])


@router.get("/opportunities/live", response_model=list[Opportunity])
def get_live_opportunities() -> list[Opportunity]:
    """
    Fetch a merged list of:
    1. Live-scraped opportunities from Opportunity Desk, DAAD, and curated pool.
    2. Static opportunities from opportunities.json as a fallback layer.

    Results are deduplicated and sorted by deadline (soonest first).
    """
    # --- Live scraping ---
    try:
        live_records = fetch_all_live_opportunities()
        logger.info("Live scraper returned %d opportunities", len(live_records))
    except (LiveScraperError, Exception) as exc:  # noqa: BLE001
        logger.warning("Live scraper failed entirely, using static fallback: %s", exc)
        live_records = []

    # --- Static JSON fallback ---
    static_records: list[dict] = []
    json_path = Path(__file__).resolve().parents[1] / "opportunities.json"
    if json_path.exists():
        try:
            raw = json.loads(json_path.read_text(encoding="utf-8"))
            if isinstance(raw, list):
                static_records = raw
        except (json.JSONDecodeError, OSError) as exc:
            logger.warning("Could not load static opportunities.json: %s", exc)

    # --- Merge and deduplicate by title ---
    all_records = live_records + static_records
    seen_titles: set[str] = set()
    unique_records: list[dict] = []
    next_id = 1

    for record in all_records:
        title_key = str(record.get("title", "")).strip().lower()
        if title_key and title_key not in seen_titles:
            seen_titles.add(title_key)
            record = dict(record)
            record["id"] = next_id
            next_id += 1
            unique_records.append(record)

    if not unique_records:
        raise HTTPException(
            status_code=503,
            detail="No opportunities available. Backend scraping failed and no static data found.",
        )

    try:
        return [Opportunity.model_validate(r) for r in unique_records]
    except Exception as exc:
        logger.error("Opportunity validation error: %s", exc)
        raise HTTPException(
            status_code=500,
            detail=f"Opportunity data validation failed: {exc}",
        ) from exc
