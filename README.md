# Smart Application Intelligence System

Smart Application Intelligence System is a Flutter mobile app with a FastAPI backend that helps students manage applications, evaluate SOP/CV quality, and discover opportunities with practical ranking logic.

## What This Project Includes

### Mobile App (Flutter)
- Dashboard with application status chart.
- Applications tracker backed by SQLite (add, list, delete, persistent storage).
- Opportunities screen with ranked opportunities and cached fallback data.
- Profile management for GPA, field, research level, and publications.
- SOP Analyzer screen connected to backend AI endpoint.
- CV Analyzer screen connected to backend AI endpoint.

### Backend (FastAPI)
- `GET /opportunities` for static opportunities.
- `GET /opportunities/live` for merged live + static opportunities.
- `POST /analyze-sop` for SOP analysis.
- `POST /analyze-cv` for CV-to-opportunity fit analysis.
- Graceful fallback behavior when live scraping fails.

## Tech Stack

- Flutter, Dart
- FastAPI, Pydantic
- SQLite (`sqflite`, `sqflite_common_ffi`)
- Requests, BeautifulSoup, lxml
- Gemini API (optional for SOP/CV AI endpoints)

## Project Structure

```text
backend/
  main.py
  requirements.txt
  opportunities.json
  models/
  routes/
  scraper/
  services/
lib/
  database/
  models/
  screens/
  services/
  widgets/
test/
  widget_test.dart
  intelligence_service_test.dart
```

## Prerequisites

Install these before running:

1. Git
2. Python 3.10+ (3.11 recommended)
3. Flutter SDK (with Android tooling)
4. Android Emulator or physical device

## Reviewer Quick Start (Windows, PowerShell)

Follow these steps exactly.

### 1. Clone and open the project

```powershell
git clone https://github.com/aliakarma/Mobile-App-Repo.git
cd Mobile-App-Repo
```

### 2. Create Python environment and install backend dependencies

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r backend/requirements.txt
```

If PowerShell blocks script activation:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

Then run activation again.

### 3. (Optional) Configure Gemini for SOP/CV AI analysis

If you want `/analyze-sop` and `/analyze-cv` to return real AI results, set API key in the same terminal where backend will run:

```powershell
$env:GEMINI_API_KEY="your_key_here"
$env:GEMINI_MODEL="gemini-1.5-flash"
```

If this is not set, SOP/CV endpoints will return a clear error message, while non-AI features still work.

### 4. Start backend server

```powershell
cd backend
python -m uvicorn main:app --reload --host 127.0.0.1 --port 8000
```

Backend should be available at:

- `http://127.0.0.1:8000/`
- `http://127.0.0.1:8000/docs`

### 5. Run Flutter app (new terminal)

Open a second terminal in project root:

```powershell
cd C:\Users\Ali Akarma\Documents\GitHub\Mobile-App-Repo
flutter pub get
flutter run
```

## Base URL Behavior (Important)

The app is configured as follows:

- Android emulator: `http://10.0.2.2:8000`
- Web/Desktop: `http://localhost:8000`

So a single backend instance on port `8000` is enough for app features.

## 3-Minute Reviewer Validation Checklist

After app launches:

1. Open Profile tab and save profile values.
2. Open Applications tab and add an application.
3. Verify it appears in list, then navigate away and back (persistence check).
4. Delete one record and verify list refresh.
5. Open Dashboard and verify chart updates from saved data.
6. Open Opportunities and verify data loads.
7. Open SOP Analyzer or CV Analyzer and run analysis:
   - With Gemini key: expect structured analysis response.
   - Without Gemini key: expect clear backend error about missing key.

## API Endpoints

| Method | Endpoint | Purpose |
|---|---|---|
| GET | `/` | Health/status response |
| GET | `/opportunities` | Static opportunities from JSON |
| GET | `/opportunities/live` | Live scraped + static merged opportunities |
| POST | `/analyze-sop` | SOP analysis (Gemini-backed) |
| POST | `/analyze-cv` | CV fit analysis against target opportunity (Gemini-backed) |

## Testing and Quality Checks

From project root:

```powershell
flutter analyze
flutter test
```

Quick backend import check:

```powershell
cd backend
python -c "import main; print('backend import ok')"
```

## Troubleshooting

### Error: ModuleNotFoundError: No module named 'routes'
Cause: backend started from wrong directory.

Fix: run from `backend` folder using:

```powershell
cd backend
python -m uvicorn main:app --reload --port 8000
```

### Error: Address already in use / WinError 10013
Cause: port `8000` is busy.

Fix option 1: free port 8000.

Fix option 2: run backend on another port, then update base URL in:
- `lib/services/opportunity_service.dart`
- `lib/services/sop_service.dart`
- `lib/services/cv_service.dart`

### SOP/CV endpoint returns 502 with missing key message
Cause: Gemini environment variable is not set.

Fix: set `GEMINI_API_KEY` in backend terminal before starting server.

## Progress #4 Evidence (UI linked with SQLite)

SQLite integration is implemented and used by UI:

- Database helper and CRUD: `lib/database/local_database.dart`
- Applications screen uses insert/fetch/delete via SQLite.
- Dashboard reads stored applications for status chart.

Recommended proof submission:

1. Short recording (30-60 seconds): add item, navigate tabs, return, delete item.
2. Screenshots: before add, after add, after returning to show persistence.
