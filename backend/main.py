from fastapi import FastAPI

from routes.analyze_sop import router as analyze_sop_router
from routes.opportunities import router as opportunities_router

app = FastAPI(title="Student Application System API", version="1.0.0")

app.include_router(opportunities_router)
app.include_router(analyze_sop_router)


@app.get("/")
def health_check() -> dict[str, str]:
    return {"message": "Student Application System API is running"}
