from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from app.database import get_db
from app.schemas.sales import SalesInvoiceCreate, SalesInvoiceResponse, SalesReturnCreate, SalesReturnResponse
from app.services.sales_service import SalesService
from app.core.deps import require_permission
from app.models.users import User
from app.models.payments import CustomerPayment
from app.models.sales import SalesInvoice, SalesInvoiceItem, SalesReturnItem, SalesReturn
from app.models.products import Product
from pydantic import BaseModel
from decimal import Decimal
from datetime import datetime
from sqlalchemy import func

router = APIRouter()


class InvoicePaymentResponse(BaseModel):
    payment_id: int
    payment_amount: Decimal
    payment_date: datetime | None
    notes: str | None

    class Config:
        from_attributes = True


class InvoiceItemResponse(BaseModel):
    item_id: int
    product_id: int
    product_name: str
    sold_quantity: Decimal
    unit_type: str
    unit_price: Decimal
    discount: Decimal
    total_price: Decimal
    returned_quantity: Decimal = Decimal("0")

    class Config:
        from_attributes = True


@router.get("/", response_model=list[SalesInvoiceResponse])
def list_sales(
    skip: int = Query(default=0, ge=0),
    limit: int = Query(default=50, ge=1, le=200),
    current_user: User = Depends(require_permission("sales:read")),
    db: Session = Depends(get_db),
):
    service = SalesService(db)
    invoices = service.list_invoices()
    return invoices[skip:skip + limit]


@router.get("/{invoice_id}", response_model=SalesInvoiceResponse)
def get_sale(invoice_id: int, current_user: User = Depends(require_permission("sales:read")), db: Session = Depends(get_db)):
    service = SalesService(db)
    return service.get_invoice(invoice_id)


@router.get("/{invoice_id}/items", response_model=list[InvoiceItemResponse])
def get_invoice_items(invoice_id: int, current_user: User = Depends(require_permission("sales:read")), db: Session = Depends(get_db)):
    returned_subq = (
        db.query(
            SalesReturnItem.product_id,
            func.coalesce(func.sum(SalesReturnItem.returned_quantity), 0).label("returned_qty"),
        )
        .join(SalesReturn, SalesReturn.return_id == SalesReturnItem.return_id)
        .filter(SalesReturn.original_invoice_id == invoice_id)
        .group_by(SalesReturnItem.product_id)
        .subquery()
    )

    rows = (
        db.query(
            SalesInvoiceItem.item_id,
            SalesInvoiceItem.product_id,
            Product.product_name,
            SalesInvoiceItem.sold_quantity,
            SalesInvoiceItem.unit_type,
            SalesInvoiceItem.unit_price,
            SalesInvoiceItem.discount,
            SalesInvoiceItem.total_price,
            func.coalesce(returned_subq.c.returned_qty, 0).label("returned_quantity"),
        )
        .join(Product, Product.product_id == SalesInvoiceItem.product_id)
        .outerjoin(returned_subq, returned_subq.c.product_id == SalesInvoiceItem.product_id)
        .filter(SalesInvoiceItem.invoice_id == invoice_id)
        .all()
    )
    return [
        InvoiceItemResponse(
            item_id=r.item_id,
            product_id=r.product_id,
            product_name=r.product_name,
            sold_quantity=r.sold_quantity,
            unit_type=r.unit_type,
            unit_price=r.unit_price,
            discount=r.discount,
            total_price=r.total_price,
            returned_quantity=r.returned_quantity,
        )
        for r in rows
    ]


@router.get("/{invoice_id}/payments", response_model=list[InvoicePaymentResponse])
def get_invoice_payments(invoice_id: int, current_user: User = Depends(require_permission("sales:read")), db: Session = Depends(get_db)):
    payments = (
        db.query(CustomerPayment)
        .filter(CustomerPayment.related_invoice_id == invoice_id)
        .order_by(CustomerPayment.payment_date.desc())
        .all()
    )
    return payments


@router.post("/", response_model=SalesInvoiceResponse, status_code=201)
def create_sale(data: SalesInvoiceCreate, current_user: User = Depends(require_permission("sales:write")), db: Session = Depends(get_db)):
    service = SalesService(db)
    return service.create_invoice(data)


@router.post("/{invoice_id}/returns", response_model=SalesReturnResponse, status_code=201)
def create_return(invoice_id: int, data: SalesReturnCreate, current_user: User = Depends(require_permission("sales:write")), db: Session = Depends(get_db)):
    service = SalesService(db)
    return service.process_return(invoice_id, data)


@router.get("/{invoice_id}/returns", response_model=list[SalesReturnResponse])
def get_returns(invoice_id: int, current_user: User = Depends(require_permission("sales:read")), db: Session = Depends(get_db)):
    service = SalesService(db)
    return service.repo.get_returns_for_invoice(invoice_id)


class SalesInvoiceUpdate(BaseModel):
    notes: str | None = None
    warehouse_notes: str | None = None


@router.put("/{invoice_id}", response_model=SalesInvoiceResponse)
def update_sale(
    invoice_id: int,
    data: SalesInvoiceUpdate,
    current_user: User = Depends(require_permission("sales:write")),
    db: Session = Depends(get_db),
):
    """Update editable fields on a sales invoice (notes only — amounts are immutable)."""
    invoice = db.query(SalesInvoice).filter(SalesInvoice.invoice_id == invoice_id).first()
    if not invoice:
        raise HTTPException(status_code=404, detail="Sales invoice not found")
    if data.notes is not None:
        invoice.notes = data.notes
    if data.warehouse_notes is not None:
        invoice.warehouse_notes = data.warehouse_notes
    db.commit()
    db.refresh(invoice)
    return invoice


class CancelRequest(BaseModel):
    reason: str | None = None


@router.post("/{invoice_id}/cancel", response_model=SalesInvoiceResponse)
def cancel_sale(
    invoice_id: int,
    data: CancelRequest = CancelRequest(),
    current_user: User = Depends(require_permission("sales:write")),
    db: Session = Depends(get_db),
):
    """Cancel a sales invoice. Only unpaid/partial invoices can be cancelled.
    Reverses inventory, ledger entries, cash transactions, and customer balance.
    """
    from app.services.inventory_service import InventoryService
    from app.services.ledger_service import LedgerService, ACCOUNT_CODES
    from app.models.accounting import LedgerEntry
    from app.models.payments import CashTransaction
    from app.models.customers import Customer

    invoice = db.query(SalesInvoice).filter(SalesInvoice.invoice_id == invoice_id).first()
    if not invoice:
        raise HTTPException(status_code=404, detail="Sales invoice not found")
    if invoice.payment_status == "paid":
        raise HTTPException(status_code=400, detail="Cannot cancel a fully paid invoice. Process a return instead.")
    if invoice.payment_status == "cancelled":
        raise HTTPException(status_code=400, detail="Invoice is already cancelled.")

    inventory_service = InventoryService(db)

    # 1. Restore inventory for each item
    items = db.query(SalesInvoiceItem).filter(SalesInvoiceItem.invoice_id == invoice_id).all()
    for item in items:
        inventory_service.record_return(
            product_id=item.product_id,
            warehouse_id=invoice.warehouse_id,
            quantity=item.sold_quantity,
            unit_type=item.unit_type,
            cost_per_unit=item.cost_at_sale,
            reference_id=invoice_id,
        )

    # 2. Reverse ledger entries for this invoice
    db.query(LedgerEntry).filter(
        LedgerEntry.entity_type == "sales_invoice",
        LedgerEntry.entity_id == invoice_id,
    ).delete()

    # 3. Reverse cash transactions
    db.query(CashTransaction).filter(
        CashTransaction.entity_type == "sales_invoice",
        CashTransaction.entity_id == invoice_id,
    ).delete()

    # 4. Reverse customer balance if credit invoice
    if invoice.customer_id and invoice.remaining_amount > 0:
        customer = db.query(Customer).filter(Customer.customer_id == invoice.customer_id).first()
        if customer:
            customer.current_balance -= invoice.remaining_amount

    # 5. Mark as cancelled
    invoice.payment_status = "cancelled"
    invoice.notes = f"{invoice.notes or ''}\n[CANCELLED] {data.reason or ''}".strip()
    db.commit()
    db.refresh(invoice)
    return invoice
