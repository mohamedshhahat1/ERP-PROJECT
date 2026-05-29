from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from sqlalchemy import func
from datetime import date, timedelta
from app.database import get_db
from app.core.deps import require_permission
from app.models.users import User
from app.models.accounting import LedgerEntry, Account, DailyFinancialSummary

router = APIRouter()


@router.get("/ledger")
def get_ledger_entries(
    skip: int = Query(default=0, ge=0),
    limit: int = Query(default=50, ge=1, le=200),
    entity_type: str | None = None,
    current_user: User = Depends(require_permission("accounting:read")),
    db: Session = Depends(get_db),
):
    query = db.query(LedgerEntry).order_by(LedgerEntry.entry_date.desc())
    if entity_type:
        query = query.filter(LedgerEntry.entity_type == entity_type)
    entries = query.offset(skip).limit(limit).all()
    return [
        {
            "entry_id": e.entry_id,
            "entry_date": str(e.entry_date),
            "account_id": e.account_id,
            "debit": str(e.debit),
            "credit": str(e.credit),
            "entity_type": e.entity_type,
            "entity_id": e.entity_id,
            "description": e.description,
        }
        for e in entries
    ]


@router.get("/trial-balance")
def get_trial_balance(
    current_user: User = Depends(require_permission("accounting:read")),
    db: Session = Depends(get_db),
):
    accounts = db.query(Account).filter(Account.active_status == True).all()
    result = []
    for acc in accounts:
        totals = db.query(
            func.coalesce(func.sum(LedgerEntry.debit), 0).label("total_debit"),
            func.coalesce(func.sum(LedgerEntry.credit), 0).label("total_credit"),
        ).filter(LedgerEntry.account_id == acc.account_id).first()

        debit = float(totals.total_debit)
        credit = float(totals.total_credit)
        balance = debit - credit if acc.account_type in ('asset', 'expense') else credit - debit

        result.append({
            "account_id": acc.account_id,
            "account_code": acc.account_code,
            "account_name": acc.account_name,
            "account_type": acc.account_type,
            "total_debit": f"{debit:.2f}",
            "total_credit": f"{credit:.2f}",
            "balance": f"{balance:.2f}",
        })
    return {"accounts": result, "total_debit": f"{sum(float(r['total_debit']) for r in result):.2f}", "total_credit": f"{sum(float(r['total_credit']) for r in result):.2f}"}


@router.get("/accounts")
def get_accounts(
    current_user: User = Depends(require_permission("accounting:read")),
    db: Session = Depends(get_db),
):
    accounts = db.query(Account).all()
    return [
        {
            "account_id": a.account_id,
            "account_code": a.account_code,
            "account_name": a.account_name,
            "account_type": a.account_type,
            "is_system": a.is_system,
        }
        for a in accounts
    ]
