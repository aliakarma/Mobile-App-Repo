import json
from pathlib import Path

from fastapi import APIRouter, HTTPException

from models.opportunity import Opportunity

router = APIRouter(tags=["opportunities"])


@router.get("/opportunities", response_model=list[Opportunity])
def get_opportunities() -> list[Opportunity]:
    json_path = Path(__file__).resolve().parents[1] / "opportunities.json"

    if not json_path.exists():
        raise HTTPException(status_code=404, detail="opportunities.json not found")

    try:
        raw_data = json.loads(json_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise HTTPException(
            status_code=500,
            detail=f"Invalid opportunities.json format: {exc.msg}",
        ) from exc

    opportunities: list[Opportunity] = [
        Opportunity.model_validate(item) for item in raw_data
    ]
    return opportunities
