from pydantic import BaseModel, HttpUrl


class Opportunity(BaseModel):
    id: int
    title: str
    provider: str
    deadline: str
    eligibility: str
    link: HttpUrl
