# Smart Application Intelligence System

Smart Application Intelligence System is a mobile-first Flutter app with a FastAPI backend designed to help students track applications, evaluate SOP quality, and prioritize opportunities using practical scoring logic.

## Features

- Bottom-tab mobile experience for Dashboard, Applications, Opportunities, and Profile.
- SQLite-based Applications Tracker with add, list, and delete operations.
- Automatic application intelligence on insert:
  - Fit Score
  - Risk Level
  - Recommendation (Apply, Prepare More, Skip)
- Profile-based scoring inputs persisted locally:
  - GPA
  - Field of study
  - Research experience level
  - Publications
- Opportunities fetched from FastAPI and ranked using fit + deadline proximity.
- Top-3 opportunities visually highlighted.
- SOP Analyzer screen in Flutter with backend POST integration.
- Dashboard chart showing application counts by status.
- FastAPI endpoints for opportunities and SOP analysis.
- Scholarship scraper module (BeautifulSoup) producing JSON data source.

## Screenshots

- Dashboard: `docs/screenshots/dashboard.png`
- Applications: `docs/screenshots/applications.png`
- Opportunities: `docs/screenshots/opportunities.png`
- Profile + SOP Analyzer: `docs/screenshots/profile-sop.png`

Replace these placeholder paths with real screenshots when publishing updates.

## Tech Stack

### Mobile App
- Flutter
- Dart
- sqflite
- shared_preferences
- http
- fl_chart

### Backend
- FastAPI
- Pydantic
- requests
- BeautifulSoup4

## Architecture

### Flutter
- `lib/screens`: UI pages and interaction flows
- `lib/models`: typed data models
- `lib/services`: API clients, local profile service, and intelligence logic
- `lib/database`: SQLite helper and CRUD logic
- `lib/widgets`: reusable visual components

### FastAPI
- `backend/main.py`: API bootstrap
- `backend/routes`: endpoint handlers
- `backend/models`: request/response schemas
- `backend/services`: Gemini SOP integration logic
- `backend/scraper`: scraping and JSON export utilities

## Setup Instructions

## 1. Clone repository

```bash
git clone https://github.com/aliakarma/Mobile-App-Repo.git
cd Mobile-App-Repo
```

## 2. Run FastAPI backend

From the repository root, run:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r backend/requirements.txt
cd backend
python -m uvicorn main:app --reload --port 8000
```

Backend runs at `http://127.0.0.1:8000`.

Quick check:

- Open `http://127.0.0.1:8000/` in your browser. You should see: `{"message":"Student Application System API is running"}`.

If PowerShell blocks script execution, run this once in the same terminal and activate again:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

Common errors and fixes:

- `ModuleNotFoundError: No module named 'routes'`
  - Cause: server started from repo root with `backend.main:app`.
  - Fix: run from `backend` folder using `python -m uvicorn main:app --reload --port 8000`.
- `[WinError 10013] ... access permissions`
  - Cause: port `8000` is already in use.
  - Fix: use another port, for example:

```powershell
python -m uvicorn main:app --reload --port 8001
```

## 3. Configure backend access for Flutter

- Android emulator: keep default base URL `http://10.0.2.2:8000`
- Physical device: replace with your machine LAN IP in Flutter services
- If you started backend on a different port (for example `8001`), update the Flutter base URL to the same port.

## 4. Run Flutter app

```bash
flutter pub get
flutter run
```

## 5. Optional Gemini configuration for SOP endpoint

Set environment variables before running backend:

```bash
set GEMINI_API_KEY=your_key_here
set GEMINI_MODEL=gemini-1.5-flash
```

## Core Workflows

- Save profile details in Profile tab.
- Add applications in Applications tab.
- System auto-calculates fit, risk, and recommendation and stores values in SQLite.
- Review ranked opportunities in Opportunities tab.
- View status distribution chart in Dashboard.
- Analyze SOP from Profile -> SOP Analyzer.

## How It Works

- Fit Score: Combines profile quality (GPA, field alignment, research, publications) into a score from 0 to 100.
- Risk Level: Uses deadline urgency and readiness to classify each application as Low, Medium, or High risk.
- Recommendation:
  - Apply: strong fit and readiness
  - Prepare More: promising but incomplete preparation
  - Skip: low fit or high urgency with low readiness
- Opportunity Ranking: Blends fit score and deadline proximity, then highlights the top 3.

## Demo Steps

- Start backend and Flutter app.
- Open Profile tab and save academic profile details.
- Add one or more applications from Applications tab.
- Confirm fit score, risk level, recommendation, and reason are generated automatically.
- Open Opportunities tab and verify ranked results with top-3 highlights.
- Open Dashboard to view status distribution chart.
- Run SOP analysis from Profile -> Open SOP Analyzer.

## Notes

- The project uses simple and explainable formulas to keep decisions transparent.
- Backend opportunities can be sourced from JSON generated by the scraper.
