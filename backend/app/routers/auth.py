from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
from app.database import get_db
from app.models.users import User
from app.core.security import verify_password, hash_password, create_access_token, decode_access_token
from app.core.deps import get_current_user
from app.core.redis import get_redis
from app.services.cache_service import CacheService
from app.schemas.users import LoginRequest, TokenResponse, ChangePasswordRequest, UserCreate, UserResponse
from app.config import settings

router = APIRouter()


@router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
def register(
    data: UserCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Create a new user. Only admins can register new accounts."""
    if current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only administrators can create new users.",
        )
    existing = db.query(User).filter(User.username == data.username).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Username already exists",
        )
    valid_roles = ("admin", "manager", "cashier", "warehouse_employee", "accountant")
    if data.role not in valid_roles:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid role. Must be one of: {', '.join(valid_roles)}",
        )
    user = User(
        full_name=data.full_name,
        username=data.username,
        password=hash_password(data.password),
        role=data.role,
        active_status=True,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@router.post("/login", response_model=TokenResponse)
def login(data: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.username == data.username).first()

    if not user or not verify_password(data.password, user.password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="We couldn't sign you in with those credentials.",
        )

    if not user.active_status:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Your account has been deactivated. Please contact support.",
        )
    user.last_login = datetime.utcnow()
    db.commit()

    token = create_access_token({"sub": str(user.user_id), "role": user.role})

    cache = CacheService(get_redis())
    cache.set_session(user.user_id, {
        "user_id": user.user_id,
        "username": user.username,
        "role": user.role,
        "full_name": user.full_name,
        "login_time": datetime.utcnow().isoformat(),
    })

    return TokenResponse(
        access_token=token,
        user_id=user.user_id,
        full_name=user.full_name,
        role=user.role,
    )


@router.get("/me", response_model=TokenResponse)
def get_me(current_user: User = Depends(get_current_user)):
    return TokenResponse(
        access_token="",
        user_id=current_user.user_id,
        full_name=current_user.full_name,
        role=current_user.role,
    )


@router.post("/refresh", response_model=TokenResponse)
def refresh_token(current_user: User = Depends(get_current_user)):
    """Issue a new access token for an authenticated user.

    The client should call this before the current token expires
    (e.g., when receiving a 401 or proactively before expiry).
    The existing token is validated via get_current_user — if it's
    already expired, the user must re-login.
    """
    if not current_user.active_status:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account deactivated. Cannot refresh token.",
        )
    new_token = create_access_token({"sub": str(current_user.user_id), "role": current_user.role})

    # Update session in cache
    cache = CacheService(get_redis())
    cache.set_session(current_user.user_id, {
        "user_id": current_user.user_id,
        "username": current_user.username,
        "role": current_user.role,
        "full_name": current_user.full_name,
        "login_time": datetime.utcnow().isoformat(),
    })

    return TokenResponse(
        access_token=new_token,
        user_id=current_user.user_id,
        full_name=current_user.full_name,
        role=current_user.role,
    )


@router.post("/change-password")
def change_password(data: ChangePasswordRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    if not verify_password(data.current_password, current_user.password):
        raise HTTPException(status_code=400, detail="Current password is incorrect")
    current_user.password = hash_password(data.new_password)
    db.commit()
    return {"detail": "Password changed successfully"}


@router.post("/logout")
def logout(current_user: User = Depends(get_current_user)):
    cache = CacheService(get_redis())
    cache.invalidate_session(current_user.user_id)
    return {"detail": "Logged out successfully"}
