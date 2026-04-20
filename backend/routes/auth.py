from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from models.auth import (
    AuthTokenResponse,
    AuthUserResponse,
    LoginRequest,
    LogoutResponse,
    SignUpRequest,
)
from services.auth_service import (
    AuthUserRecord,
    authenticate_user,
    create_access_token,
    create_user,
    decode_access_token,
    get_user_by_id,
)

router = APIRouter(prefix="/auth", tags=["authentication"])
_bearer_scheme = HTTPBearer(auto_error=False)


def _get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer_scheme),
) -> AuthUserRecord:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required.",
        )

    try:
        payload = decode_access_token(credentials.credentials)
    except ValueError as error:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(error),
        ) from error

    user_id_raw = payload.get("sub")
    if user_id_raw is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token payload.",
        )

    try:
        user_id = int(user_id_raw)
    except (TypeError, ValueError) as error:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token subject.",
        ) from error

    user = get_user_by_id(user_id)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found.",
        )

    return user


@router.post(
    "/signup",
    response_model=AuthTokenResponse,
    status_code=status.HTTP_201_CREATED,
)
def sign_up(payload: SignUpRequest) -> AuthTokenResponse:
    if len(payload.password.strip()) < 8:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Password must be at least 8 characters.",
        )

    try:
        user = create_user(
            full_name=payload.full_name,
            email=payload.email,
            password=payload.password,
        )
    except ValueError as error:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(error),
        ) from error

    return _build_auth_response(user=user, remember_me=payload.remember_me)


@router.post("/login", response_model=AuthTokenResponse)
def login(payload: LoginRequest) -> AuthTokenResponse:
    user = authenticate_user(payload.email, payload.password)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password.",
        )

    return _build_auth_response(user=user, remember_me=payload.remember_me)


@router.get("/me", response_model=AuthUserResponse)
def me(current_user: AuthUserRecord = Depends(_get_current_user)) -> AuthUserResponse:
    return _to_response_user(current_user)


@router.post("/logout", response_model=LogoutResponse)
def logout(_current_user: AuthUserRecord = Depends(_get_current_user)) -> LogoutResponse:
    # This API keeps JWT auth stateless. Client-side token removal completes logout.
    return LogoutResponse(message="Logged out successfully.")


def _build_auth_response(
    *,
    user: AuthUserRecord,
    remember_me: bool,
) -> AuthTokenResponse:
    token, expires_in = create_access_token(user=user, remember_me=remember_me)
    return AuthTokenResponse(
        access_token=token,
        expires_in=expires_in,
        user=_to_response_user(user),
    )


def _to_response_user(user: AuthUserRecord) -> AuthUserResponse:
    return AuthUserResponse(
        id=user.id,
        full_name=user.full_name,
        email=user.email,
        created_at=user.created_at,
    )
