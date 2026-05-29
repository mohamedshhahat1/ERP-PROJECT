"""Smart Invoice Router — AI-powered invoice creation from photos."""
from fastapi import APIRouter, Depends, UploadFile, File, Form, HTTPException
from sqlalchemy.orm import Session
from app.database import get_db
from app.core.deps import require_permission
from app.models.users import User
from app.services.invoice_ai_pipeline import InvoiceAIPipeline
from app.services.ocr_service import OCRService
from app.services.invoice_parser import InvoiceParser
import logging

router = APIRouter()
logger = logging.getLogger(__name__)


@router.post("/extract")
async def extract_invoice_from_image(
    file: UploadFile = File(...),
    language: str = Form(default="ar"),
    current_user: User = Depends(require_permission("sales:write")),
    db: Session = Depends(get_db),
):
    """Full pipeline: Image → Duplicate Check → PaddleOCR → Claude AI → Quantity Normalization → Product Matching → Semantic Matching → Invoice Data"""
    # Validate file
    image_data = await file.read()
    if len(image_data) > 20 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="Image too large. Maximum 20MB.")

    content_type = file.content_type or "image/jpeg"
    if content_type not in ("image/jpeg", "image/png", "image/gif", "image/webp"):
        raise HTTPException(status_code=400, detail="Unsupported format. Use JPEG, PNG, GIF, or WebP.")

    # Run pipeline
    pipeline = InvoiceAIPipeline(db)
    result = pipeline.process_image(image_data)

    # If duplicate detected, return 409 Conflict with details
    if result.get("status") == "duplicate":
        return {
            "status": "duplicate",
            "duplicate_check": result.get("duplicate_check"),
            "pipeline": result.get("pipeline"),
            "message": result.get("error", "Duplicate invoice detected"),
        }

    return result


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
