"""Smart Invoice Router — AI-powered invoice creation from photos."""
from fastapi import APIRouter, Depends, UploadFile, File, Form, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel, Field
from decimal import Decimal
from app.database import get_db, transaction
from app.core.deps import require_permission
from app.models.users import User
from app.services.invoice_ai_pipeline import InvoiceAIPipeline
from app.services.ocr_service import OCRService
from app.services.invoice_parser import InvoiceParser
from app.services.duplicate_detector import DuplicateDetector
from app.services.sales_service import SalesService
from app.schemas.sales import SalesInvoiceCreate, SalesItemCreate
import logging

router = APIRouter()
logger = logging.getLogger(__name__)


# --- Schema for creating invoice from extracted data ---

class SmartInvoiceItem(BaseModel):
    product_id: int
    quantity: float = Field(gt=0)
    unit_type: str = "meter"
    unit_price: float = Field(ge=0)
    cost_at_sale: float = 0

class SmartInvoiceCreate(BaseModel):
    """Create an invoice from smart-extracted data (all-or-nothing)."""
    customer_id: int | None = None
    invoice_type: str = "cash"  # cash, credit, mixed
    warehouse_id: int = 1
    items: list[SmartInvoiceItem] = Field(min_length=1)
    discount_amount: float = 0
    paid_amount: float = 0
    notes: str | None = None
    image_hash: str | None = None  # For duplicate registration after success


@router.post("/extract")
async def extract_invoice_from_image(
    file: UploadFile = File(...),
    language: str = Form(default="ar"),
    current_user: User = Depends(require_permission("sales:write")),
    db: Session = Depends(get_db),
):
    """Full pipeline: Image → Duplicate Check → PaddleOCR → Claude AI → Quantity Normalization → Product Matching → Semantic Matching → Invoice Data"""
    image_data = await file.read()
    if len(image_data) > 20 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="Image too large. Maximum 20MB.")

    content_type = file.content_type or "image/jpeg"
    if content_type not in ("image/jpeg", "image/png", "image/gif", "image/webp"):
        raise HTTPException(status_code=400, detail="Unsupported format. Use JPEG, PNG, GIF, or WebP.")

    pipeline = InvoiceAIPipeline(db)
    result = pipeline.process_image(image_data)

    if result.get("status") == "duplicate":
        return {
            "status": "duplicate",
            "duplicate_check": result.get("duplicate_check"),
            "pipeline": result.get("pipeline"),
            "message": result.get("error", "Duplicate invoice detected"),
        }

    return result


@router.post("/create", status_code=201)
def create_invoice_from_extraction(
    data: SmartInvoiceCreate,
    current_user: User = Depends(require_permission("sales:write")),
    db: Session = Depends(get_db),
):
    """Create invoice from extracted/confirmed data — FULLY ATOMIC.

    This is the final step after the user reviews extracted data.
    The entire flow is wrapped in a single database transaction:
      1. Create invoice record
      2. Create invoice items
      3. Deduct inventory (with row-level lock)
      4. Record cash transaction (if paid)
      5. Record ledger entries (revenue, COGS, receivables)
      6. Update customer balance (if credit)

    If ANY step fails → everything rolls back to zero.
    Only after full success → registers the image hash to prevent re-upload.
    """
    try:
        # Build the SalesInvoiceCreate schema from smart invoice data
        items = [
            SalesItemCreate(
                product_id=item.product_id,
                sold_quantity=Decimal(str(item.quantity)),
                unit_type=item.unit_type,
                unit_price=Decimal(str(item.unit_price)),
                cost_at_sale=Decimal(str(item.cost_at_sale)),
                total_price=Decimal(str(item.quantity * item.unit_price)),
            )
            for item in data.items
        ]

        invoice_number = f"SI-{__import__('time').time_ns() // 1_000_000 % 10_000_000:07d}"

        invoice_data = SalesInvoiceCreate(
            customer_id=data.customer_id,
            invoice_number=invoice_number,
            invoice_type=data.invoice_type,
            warehouse_id=data.warehouse_id,
            discount_amount=Decimal(str(data.discount_amount)),
            paid_amount=Decimal(str(data.paid_amount)),
            notes=f"[Smart Invoice] {data.notes or ''}".strip(),
            items=items,
        )

        # This is ALREADY atomic — SalesService.create_invoice uses `with transaction(db):`
        # which wraps: create invoice + items + inventory deduction + cash + ledger + customer balance
        service = SalesService(db)
        invoice = service.create_invoice(invoice_data)

        # Only AFTER successful creation, register the image hash
        if data.image_hash:
            detector = DuplicateDetector(db)
            detector.register_processed(
                image_bytes=data.image_hash.encode(),  # Use hash directly
                invoice_id=invoice.invoice_id,
            )

        return {
            "status": "success",
            "invoice_id": invoice.invoice_id,
            "invoice_number": invoice.invoice_number,
            "total_amount": str(invoice.total_amount),
            "payment_status": invoice.payment_status,
            "message": "تم إنشاء الفاتورة بنجاح من الصورة",
        }

    except Exception as e:
        # Transaction already rolled back by SalesService
        logger.error(f"Smart invoice creation failed: {e}")
        raise HTTPException(
            status_code=400,
            detail=f"فشل إنشاء الفاتورة: {str(e)}",
        )


@router.post("/ocr-only")
async def ocr_only(
    file: UploadFile = File(...),
    current_user: User = Depends(require_permission("sales:write")),
):
    """OCR only — extract raw text from image without AI parsing."""
    image_data = await file.read()
    if len(image_data) > 20 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="Image too large. Maximum 20MB.")

    ocr = OCRService.get_instance()
    result = ocr.extract_text(image_data)
    return result


@router.post("/parse-text")
async def parse_text(
    text: str = Form(...),
    language: str = Form(default="ar"),
    current_user: User = Depends(require_permission("sales:write")),
):
    """Parse raw text into invoice structure using Claude AI (without OCR step)."""
    parser = InvoiceParser()
    result = parser.parse(text, language=language)
    return result
