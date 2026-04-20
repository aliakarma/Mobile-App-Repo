from __future__ import annotations

import os
import sqlite3
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

from jose import JWTError, jwt
from passlib.context import CryptContext


_pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
_algorithm = "HS256"
_access_token_expire_minutes = int(
    os.getenv("AUTH_ACCESS_TOKEN_EXPIRE_MINUTES", "1440")
)
_access_token_remember_expire_minutes = int(
    os.getenv("AUTH_ACCESS_TOKEN_REMEMBER_ME_EXPIRE_MINUTES", "43200")
)
_secret_key = os.getenv("AUTH_SECRET_KEY", "replace-this-with-a-strong-secret")

_base_dir = Path(__file__).resolve().parents[1]
_db_dir = _base_dir / "data"
_db_path = _db_dir / "auth.db"


@dataclass(frozen=True)
class AuthUserRecord:
    id: int
    full_name: str
    email: str
    password_hash: str
    created_at: str


def init_auth_db() -> None:
    _db_dir.mkdir(parents=True, exist_ok=True)
    with _get_connection() as connection:
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                full_name TEXT NOT NULL,
                email TEXT NOT NULL UNIQUE COLLATE NOCASE,
                password_hash TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
            """
        )
        connection.commit()


def get_user_by_email(email: str) -> AuthUserRecord | None:
    normalized_email = _normalize_email(email)
    with _get_connection() as connection:
        row = connection.execute(
            """
            SELECT id, full_name, email, password_hash, created_at
            FROM users
            WHERE email = ?
            """,
            (normalized_email,),
        ).fetchone()
    return _row_to_user(row)


def get_user_by_id(user_id: int) -> AuthUserRecord | None:
    with _get_connection() as connection:
        row = connection.execute(
            """
            SELECT id, full_name, email, password_hash, created_at
            FROM users
            WHERE id = ?
            """,
            (user_id,),
        ).fetchone()
    return _row_to_user(row)


def create_user(full_name: str, email: str, password: str) -> AuthUserRecord:
    normalized_email = _normalize_email(email)
    now_iso = datetime.now(timezone.utc).isoformat()
    password_hash = get_password_hash(password)

    try:
        with _get_connection() as connection:
            cursor = connection.execute(
                """
                INSERT INTO users (full_name, email, password_hash, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?)
                """,
                (full_name.strip(), normalized_email, password_hash, now_iso, now_iso),
            )
            connection.commit()
            user_id = int(cursor.lastrowid)
    except sqlite3.IntegrityError as error:
        raise ValueError("An account with this email already exists.") from error

    created = get_user_by_id(user_id)
    if created is None:
        raise RuntimeError("Failed to create user account.")
    return created


def authenticate_user(email: str, password: str) -> AuthUserRecord | None:
    user = get_user_by_email(email)
    if user is None:
        return None
    if not verify_password(password, user.password_hash):
        return None
    return user


def create_access_token(
    *,
    user: AuthUserRecord,
    remember_me: bool = False,
) -> tuple[str, int]:
    expiry_minutes = (
        _access_token_remember_expire_minutes
        if remember_me
        else _access_token_expire_minutes
    )
    expires_delta = timedelta(minutes=expiry_minutes)
    expires_at = datetime.now(timezone.utc) + expires_delta

    to_encode = {
        "sub": str(user.id),
        "email": user.email,
        "exp": expires_at,
    }
    token = jwt.encode(to_encode, _secret_key, algorithm=_algorithm)
    return token, int(expires_delta.total_seconds())


def decode_access_token(token: str) -> dict[str, Any]:
    try:
        return jwt.decode(token, _secret_key, algorithms=[_algorithm])
    except JWTError as error:
        raise ValueError("Invalid or expired token.") from error


def get_password_hash(password: str) -> str:
    return _pwd_context.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    return _pwd_context.verify(plain_password, hashed_password)


def _normalize_email(email: str) -> str:
    return email.strip().lower()


def _get_connection() -> sqlite3.Connection:
    connection = sqlite3.connect(_db_path)
    connection.row_factory = sqlite3.Row
    return connection


def _row_to_user(row: sqlite3.Row | None) -> AuthUserRecord | None:
    if row is None:
        return None
    return AuthUserRecord(
        id=int(row["id"]),
        full_name=str(row["full_name"]),
        email=str(row["email"]),
        password_hash=str(row["password_hash"]),
        created_at=str(row["created_at"]),
    )
