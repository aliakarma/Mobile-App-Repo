"""
live_opportunities.py

FastAPI route for fetching real-time scholarship and internship opportunities
from live web sources. Merges live scraped data with the static opportunities.json.
"""

from __future__ import annotations

import logging
import os
from datetime import datetime, timezone
import asyncio

from fastapi import APIRouter, BackgroundTasks, HTTPException

from ..models.opportunity import Opportunity, OpportunitiesCacheResponse
from ..services.opportunities_cache_service import (
    get_cached_live_opportunities,
    refresh_live_opportunities_cache,
)

logger = logging.getLogger(__name__)

router = APIRouter(tags=["opportunities"])


def _cache_ttl_seconds() -> int:
    raw = os.getenv("OPPORTUNITIES_CACHE_TTL_SECONDS", "3600").strip()
    try:
        value = int(raw)
    except ValueError:
        value = 3600
    return max(60, value)


async def _refresh_in_thread() -> None:
    await asyncio.to_thread(refresh_live_opportunities_cache)


@router.get("/opportunities/live", response_model=OpportunitiesCacheResponse)
async def get_live_opportunities(
    background_tasks: BackgroundTasks,
) -> OpportunitiesCacheResponse:
    """
    Return cached opportunities plus a cache timestamp.

    When the cache is stale/missing, a refresh is scheduled in the background
    (stale-while-revalidate) so scraping does not run in the request path.
    """
    cached = get_cached_live_opportunities()
    ttl_seconds = _cache_ttl_seconds()

    if cached is None:
        background_tasks.add_task(_refresh_in_thread)
        raise HTTPException(
            status_code=503,
            detail="Opportunities cache is warming up. Please retry shortly.",
        )

    records, updated_at = cached

    try:
        updated_dt = datetime.fromisoformat(updated_at)
        if updated_dt.tzinfo is None:
            updated_dt = updated_dt.replace(tzinfo=timezone.utc)
    except ValueError:
        updated_dt = datetime.now(timezone.utc)

    age_seconds = (datetime.now(timezone.utc) - updated_dt).total_seconds()
    if age_seconds > ttl_seconds:
        background_tasks.add_task(_refresh_in_thread)

    try:
        opportunities = [Opportunity.model_validate(r) for r in records]
    except Exception as exc:
        logger.error("Opportunity validation error (cached payload): %s", exc)
        raise HTTPException(
            status_code=500,
            detail="Cached opportunities payload is invalid.",
        ) from exc

    return OpportunitiesCacheResponse(updated_at=updated_at, opportunities=opportunities)
