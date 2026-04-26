from __future__ import annotations

import sys
from pathlib import Path

import uvicorn


def main() -> None:
    backend_dir = Path(__file__).resolve().parent
    repo_root = backend_dir.parent

    # Ensure `backend.main` is importable even when launched from `backend/`.
    repo_root_str = str(repo_root)
    if repo_root_str not in sys.path:
        sys.path.insert(0, repo_root_str)

    uvicorn.run(
        "backend.main:app",
        host="127.0.0.1",
        port=8001,
        reload=True,
        reload_dirs=[str(backend_dir)],
    )


if __name__ == "__main__":
    main()
