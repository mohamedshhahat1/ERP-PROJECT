from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.database import get_db
from app.schemas.opening_balance import (
    CustomerOpeningBalanceCreate,
    SupplierOpeningBalanceCreate,
    CashOpeningBalanceCreate,
)
from app.services.opening_balance_service import OpeningBalanceService
from app.core.deps import require_permission, require_admin
from app.core.redis import get_redis
from app.models.users import User

router = APIRouter()

LOCK_KEY = "opening_balances:locked"


def _is_locked() -> bool:
    """Check if opening balances are locked."""
    redis = get_redis()
    return redis.get(LOCK_KEY) == "true"


def _require_unlocked():
    """Raise 403 if opening balances are locked."""
    if _is_locked():
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Opening balances are locked. An admin must unlock them before changes can be made.",
        )


@router.get("/lock-status")
def get_lock_status(current_user: User = Depends(require_permission("accounting:read"))):
    """Check if opening balances are locked."""
    return {"locked": _is_locked()}


@router.post("/lock")
def lock_opening_balances(current_user: User = Depends(require_admin)):
    """Lock opening balances (admin only). Prevents any further changes."""
    redis = get_redis()
    redis.set(LOCK_KEY, "true")
    return {"detail": "Opening balances have been locked.", "locked": True}


@router.post("/unlock")
def unlock_opening_balances(current_user: User = Depends(require_admin)):
    """Unlock opening balances (admin only). Allows changes again."""
    redis = get_redis()
    redis.delete(LOCK_KEY)
    return {"detail": "Opening balances have been unlocked.", "locked": False}


@router.post("/customer", status_code=201)
def create_customer_opening_balance(
    data: CustomerOpeningBalanceCreate,
    current_user: User = Depends(require_permission("accounting:write")),
    db: Session = Depends(get_db),
):
    _require_unlocked()
    service = OpeningBalanceService(db)
    try:
        result = service.set_customer_opening_balance(
            customer_id=data.customer_id,
            amount=data.amount,
            balance_type=data.balance_type,
            notes=data.notes,
        )
        db.commit()
        return result
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.post("/supplier", status_code=201)
def create_supplier_opening_balance(
    data: SupplierOpeningBalanceCreate,
    current_user: User = Depends(require_permission("accounting:write")),
    db: Session = Depends(get_db),
):
    _require_unlocked()
    service = OpeningBalanceService(db)
    try:
        result = service.set_supplier_opening_balance(
            supplier_id=data.supplier_id,
            amount=data.amount,
            balance_type=data.balance_type,
            notes=data.notes,
        )
        db.commit()
        return result
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.post("/cash", status_code=201)
def create_cash_opening_balance(
    data: CashOpeningBalanceCreate,
    current_user: User = Depends(require_permission("accounting:write")),
    db: Session = Depends(get_db),
):
    _require_unlocked()
    service = OpeningBalanceService(db)
    result = service.set_cash_opening_balance(
        amount=data.amount,
        account_name=data.account_name,
        notes=data.notes,
    )
    db.commit()
    return result


@router.get("")
def get_opening_balances(
    entity_type: str | None = None,
    current_user: User = Depends(require_permission("accounting:read")),
    db: Session = Depends(get_db),
):
    service = OpeningBalanceService(db)
    return service.get_opening_balances(entity_type)
