from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.database import get_db
from app.schemas.suppliers import SupplierCreate, SupplierUpdate, SupplierResponse
from app.services.supplier_service import SupplierService
from app.core.deps import require_permission
from app.models.users import User
from app.models.suppliers import Supplier
from app.models.purchases import PurchaseInvoice

router = APIRouter()


@router.get("/", response_model=list[SupplierResponse])
def list_suppliers(current_user: User = Depends(require_permission("suppliers:read")), db: Session = Depends(get_db)):
    service = SupplierService(db)
    return service.list_all()


@router.get("/{supplier_id}", response_model=SupplierResponse)
def get_supplier(supplier_id: int, current_user: User = Depends(require_permission("suppliers:read")), db: Session = Depends(get_db)):
    service = SupplierService(db)
    return service.get(supplier_id)


@router.post("/", response_model=SupplierResponse, status_code=201)
def create_supplier(data: SupplierCreate, current_user: User = Depends(require_permission("suppliers:write")), db: Session = Depends(get_db)):
    service = SupplierService(db)
    return service.create(data)


@router.put("/{supplier_id}", response_model=SupplierResponse)
def update_supplier(supplier_id: int, data: SupplierUpdate, current_user: User = Depends(require_permission("suppliers:write")), db: Session = Depends(get_db)):
    service = SupplierService(db)
    return service.update(supplier_id, data)


@router.delete("/{supplier_id}", status_code=204)
def delete_supplier(supplier_id: int, current_user: User = Depends(require_permission("suppliers:write")), db: Session = Depends(get_db)):
    """Delete a supplier. Only allowed if they have no associated purchase invoices."""
    supplier = db.query(Supplier).filter(Supplier.supplier_id == supplier_id).first()
    if not supplier:
        raise HTTPException(status_code=404, detail="Supplier not found")
    has_invoices = db.query(PurchaseInvoice).filter(PurchaseInvoice.supplier_id == supplier_id).first()
    if has_invoices:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Cannot delete supplier with existing purchase invoices. Deactivate instead.",
        )
    db.delete(supplier)
    db.commit()
