"""Invoice AI Pipeline — orchestrates the full OCR → Parse → Match → Invoice flow."""
from sqlalchemy.orm import Session
from app.services.ocr_service import OCRService
from app.services.invoice_parser import InvoiceParser
from app.services.product_matcher import ProductMatcher
import logging
import time

logger = logging.getLogger(__name__)


class InvoiceAIPipeline:
    """Full pipeline: Image → OCR → AI Parsing → Product Matching → Invoice Data"""

    def __init__(self, db: Session):
        self.db = db
        self.ocr = OCRService.get_instance()
        self.parser = InvoiceParser()
        self.matcher = ProductMatcher(db)

    def process_image(self, image_bytes: bytes) -> dict:
        """Process an image through the full pipeline.

        Steps:
        1. PaddleOCR extracts raw text from image
        2. Claude AI structures the text into invoice format
        3. Product matcher links items to existing products

        Returns:
            {
                "status": "success" | "partial" | "error",
                "pipeline": {
                    "ocr": {"duration_ms": int, "lines_found": int, "language": str},
                    "parser": {"duration_ms": int, "items_found": int, "confidence": str},
                    "matcher": {"duration_ms": int, "matched": int, "unmatched": int},
                },
                "data": {
                    "customer_name": str | None,
                    "customer_phone": str | None,
                    "items": [...],
                    "discount": float,
                    "notes": str | None,
                    "payment_type": str,
                    "confidence": str,
                },
                "ocr_raw_text": str,
                "error": str | None,
            }
        """
        pipeline_stats = {}

        # Step 1: OCR
        t0 = time.time()
        ocr_result = self.ocr.extract_text(image_bytes)
        pipeline_stats["ocr"] = {
            "duration_ms": int((time.time() - t0) * 1000),
            "lines_found": len(ocr_result.get("lines", [])),
            "language": ocr_result.get("language_detected", "unknown"),
            "success": ocr_result.get("success", False),
        }

        if not ocr_result["success"]:
            return {
                "status": "error",
                "pipeline": pipeline_stats,
                "data": None,
                "ocr_raw_text": "",
                "error": ocr_result.get("error", "OCR failed"),
            }

        raw_text = ocr_result["raw_text"]
        if not raw_text.strip():
            return {
                "status": "error",
                "pipeline": pipeline_stats,
                "data": None,
                "ocr_raw_text": "",
                "error": "No text detected in image",
            }

        # Step 2: AI Parsing
        t1 = time.time()
        parsed = self.parser.parse(raw_text, language=ocr_result["language_detected"])
        pipeline_stats["parser"] = {
            "duration_ms": int((time.time() - t1) * 1000),
            "items_found": len(parsed.get("items", [])),
            "confidence": parsed.get("confidence", "low"),
            "tokens_used": parsed.get("tokens_used", 0),
        }

        if parsed.get("error") and not parsed.get("items"):
            return {
                "status": "error",
                "pipeline": pipeline_stats,
                "data": parsed,
                "ocr_raw_text": raw_text,
                "error": parsed["error"],
            }

        # Step 3: Product Matching
        t2 = time.time()
        items = parsed.get("items", [])
        if items:
            matched_items = self.matcher.match_items(items)
            matched_count = sum(1 for i in matched_items if i.get("product_id"))
        else:
            matched_items = []
            matched_count = 0

        pipeline_stats["matcher"] = {
            "duration_ms": int((time.time() - t2) * 1000),
            "matched": matched_count,
            "unmatched": len(matched_items) - matched_count,
            "total_items": len(matched_items),
        }

        # Build final result
        status = "success" if matched_count == len(matched_items) and items else "partial"

        return {
            "status": status,
            "pipeline": pipeline_stats,
            "data": {
                "customer_name": parsed.get("customer_name"),
                "customer_phone": parsed.get("customer_phone"),
                "items": matched_items,
                "discount": parsed.get("discount", 0),
                "notes": parsed.get("notes"),
                "payment_type": parsed.get("payment_type", "unknown"),
                "confidence": parsed.get("confidence", "low"),
                "parsing_notes": parsed.get("parsing_notes"),
            },
            "ocr_raw_text": raw_text,
            "error": None,
        }
