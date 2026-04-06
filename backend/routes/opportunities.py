from fastapi import APIRouter

from models.opportunity import Opportunity

router = APIRouter(tags=["opportunities"])


@router.get("/opportunities", response_model=list[Opportunity])
def get_opportunities() -> list[Opportunity]:
    return [
        Opportunity(
            id=1,
            title="Merit Excellence Scholarship",
            provider="Global Education Foundation",
            deadline="2026-08-15",
            eligibility="Undergraduate students with GPA 3.5+",
            link="https://example.org/scholarships/merit-excellence",
        ),
        Opportunity(
            id=2,
            title="STEM Leadership Grant",
            provider="Future Innovators Fund",
            deadline="2026-09-01",
            eligibility="STEM applicants with leadership experience",
            link="https://example.org/scholarships/stem-leadership",
        ),
        Opportunity(
            id=3,
            title="International Scholars Award",
            provider="Academic Horizons",
            deadline="2026-10-10",
            eligibility="International students applying for master's programs",
            link="https://example.org/scholarships/international-scholars",
        ),
    ]
