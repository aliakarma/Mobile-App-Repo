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

### 3. (Optional) Configure Gemini for SOP/CV AI analysis (safe)

Use a local backend `.env` file so your key is never committed.

1. Create `backend/.env` from the example:

```powershell
Copy-Item backend/.env.example backend/.env
```

2. Open `backend/.env` and set:

```text
AUTH_SECRET_KEY=replace_with_a_long_random_secret
GEMINI_API_KEY=your_real_key_here
GEMINI_MODEL=gemini-1.5-flash
GEMINI_CV_TIMEOUT_SECONDS=45
```

Notes:
- `backend/.env` is ignored by git via `.gitignore`.
- `backend/main.py` automatically loads `backend/.env` at startup.
- `AUTH_SECRET_KEY` is required for stable authentication tokens.
- If key is missing, `/analyze-sop` and `/analyze-cv` return a clear error while non-AI features still work.
- If `AUTH_SECRET_KEY` is missing in local development, the backend now uses a temporary fallback so startup does not fail, but setting a real value is still recommended.

Alternative (ephemeral, current terminal only):

```powershell
$env:AUTH_SECRET_KEY="replace_with_a_long_random_secret"
$env:GEMINI_API_KEY="your_key_here"
$env:GEMINI_MODEL="gemini-2.5-flash"
```

### 4. Start backend server

From the repo root:

```powershell
python backend/run_server.py
```

If your terminal is already inside `backend`:

```powershell
python run_server.py
```

Backend should be available at:

- `http://127.0.0.1:8001/`
- `http://127.0.0.1:8001/docs`

### 5. Run Flutter app (new terminal)

Open a second terminal in project root:

```powershell
cd Mobile-App-Repo
flutter pub get
flutter run
```

## Base URL Behavior (Important)

The app is configured as follows:

- Android emulator: `http://10.0.2.2:8001`
- Web/Desktop: `http://localhost:8001`

So a single backend instance on port `8001` is enough for app features.

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
cd Mobile-App-Repo
python -c "import backend.main; print('backend import ok')"
```

## Troubleshooting

### Error: ModuleNotFoundError: No module named 'backend'
Cause: `uvicorn backend.main:app` was started while the current directory was already `backend`, so Python could not see the repo root on its import path.

Permanent fix: use the launcher script, which adds the repo root to Python's import path automatically.

Use either of these:

```powershell
cd Mobile-App-Repo
python backend/run_server.py
```

```powershell
cd backend
python run_server.py
```

### Error: Address already in use / WinError 10013
Cause: port `8001` is busy.

Fix option 1: free port 8001.

Fix option 2: run backend on another port, then update base URL in:
- `lib/services/opportunity_service.dart`
- `lib/services/sop_service.dart`
- `lib/services/cv_service.dart`

### SOP/CV endpoint returns 502 with missing key message
Cause: Gemini environment variable is not set.

Fix: set `GEMINI_API_KEY` in backend terminal before starting server.

### Startup fails with `AUTH_SECRET_KEY is required for authentication`
Cause: authentication was enabled but no auth secret was configured.

Fix:
- Preferred: add `AUTH_SECRET_KEY=replace_with_a_long_random_secret` to `backend/.env`.
- Local development fallback now allows the backend to start without it, but tokens will use an insecure dev-only secret.

### CV analysis says request timed out
Cause: CV analysis, especially with longer text or PDFs, can take longer than a normal API request.

Fix:
- Pull the latest app changes in this repo, which increase the client timeout for `/analyze-cv`.
- Restart the FastAPI backend after updating `backend/.env`.
- If PDF analysis is still slow, increase `GEMINI_CV_TIMEOUT_SECONDS` in `backend/.env` to `60`.

## Progress #4 Evidence (UI linked with SQLite)

SQLite integration is implemented and used by UI:

- Database helper and CRUD: `lib/database/local_database.dart`
- Applications screen uses insert/fetch/delete via SQLite.
- Dashboard reads stored applications for status chart.

Recommended proof submission:

1. Short recording (30-60 seconds): add item, navigate tabs, return, delete item.
2. Screenshots: before add, after add, after returning to show persistence.
