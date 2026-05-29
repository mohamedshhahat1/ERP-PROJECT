"""Invoice AI Pipeline — orchestrates the full OCR → Parse → Match → Invoice flow."""
from sqlalchemy.orm import Session
from app.services.ocr_service import OCRService
from app.services.invoice_parser import InvoiceParser
from app.services.product_matcher import ProductMatcher
from app.services.semantic_matcher import SemanticMatcher
from app.services.quantity_normalizer import QuantityNormalizer
from app.services.duplicate_detector import DuplicateDetector
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
        self.semantic_matcher = SemanticMatcher(db)
        self.quantity_normalizer = QuantityNormalizer()
        self.duplicate_detector = DuplicateDetector(db)

    def process_image(self, image_bytes: bytes) -> dict:
        """Process an image through the full pipeline.

        Steps:
        1. Duplicate detection (before OCR to save resources)
        2. PaddleOCR extracts raw text from image
        3. Claude AI structures the text into invoice format
        4. Quantity normalization on parsed items
        5. Product matcher links items to existing products
        6. Semantic matching for unmatched items
        7. Register image hash for future duplicate detection

        Returns:
            {
                "status": "success" | "partial" | "error",
                "pipeline": {
                    "duplicate_check": {"duration_ms": int, "is_duplicate": bool},
                    "ocr": {"duration_ms": int, "lines_found": int, "language": str},
                    "parser": {"duration_ms": int, "items_found": int, "confidence": str},
                    "normalizer": {"duration_ms": int, "items_normalized": int},
                    "matcher": {"duration_ms": int, "matched": int, "unmatched": int},
                    "semantic_matcher": {"duration_ms": int, "additionally_matched": int},
                },
                "duplicate_check": {...},
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

        # Step 1: Duplicate Detection (before OCR to save resources)
        t_dup = time.time()
        duplicate_result = self.duplicate_detector.check_duplicate(image_bytes)
        pipeline_stats["duplicate_check"] = {
            "duration_ms": int((time.time() - t_dup) * 1000),
            "is_duplicate": duplicate_result["is_duplicate"],
            "duplicate_type": duplicate_result.get("duplicate_type"),
        }

        if duplicate_result["is_duplicate"] and duplicate_result["duplicate_type"] == "exact_image":
            return {
                "status": "duplicate",
                "pipeline": pipeline_stats,
                "duplicate_check": duplicate_result,
                "data": None,
                "ocr_raw_text": "",
                "error": duplicate_result.get("message", "Duplicate image detected"),
            }

        # Step 2: OCR
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
                "duplicate_check": duplicate_result,
                "data": None,
                "ocr_raw_text": "",
                "error": ocr_result.get("error", "OCR failed"),
            }

        raw_text = ocr_result["raw_text"]
        if not raw_text.strip():
            return {
                "status": "error",
                "pipeline": pipeline_stats,
                "duplicate_check": duplicate_result,
                "data": None,
                "ocr_raw_text": "",
                "error": "No text detected in image",
            }

        # Step 3: AI Parsing
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
                "duplicate_check": duplicate_result,
                "data": parsed,
                "ocr_raw_text": raw_text,
                "error": parsed["error"],
            }

        # Step 3.5: Content-based duplicate check (now that we have parsed data)
        if not duplicate_result["is_duplicate"]:
            content_dup = self.duplicate_detector.check_duplicate(image_bytes, extracted_data=parsed)
            if content_dup["is_duplicate"]:
                duplicate_result = content_dup
                pipeline_stats["duplicate_check"]["is_duplicate"] = True
                pipeline_stats["duplicate_check"]["duplicate_type"] = "similar_content"

        # Step 4: Quantity Normalization
        t_norm = time.time()
        items = parsed.get("items", [])
        if items:
            items = self.quantity_normalizer.normalize_items(items)
        pipeline_stats["normalizer"] = {
            "duration_ms": int((time.time() - t_norm) * 1000),
            "items_normalized": len(items),
        }

        # Step 5: Product Matching
        t2 = time.time()
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

        # Step 6: Semantic Matching for unmatched items
        t_sem = time.time()
        additionally_matched = 0
        for item in matched_items:
            if not item.get("product_id") and item.get("product_name"):
                # Try semantic matching
                try:
                    similar = self.semantic_matcher.find_similar_products(
                        item["product_name"], limit=1
                    )
                    if similar:
                        best = similar[0]
                        item["product_id"] = best["product_id"]
                        item["matched_product_name"] = best["product_name"]
                        item["match_confidence"] = best["similarity"]
                        item["match_method"] = best["method"]
                        additionally_matched += 1
                except Exception as e:
                    logger.debug(f"Semantic matching failed for '{item.get('product_name')}': {e}")

        pipeline_stats["semantic_matcher"] = {
            "duration_ms": int((time.time() - t_sem) * 1000),
            "additionally_matched": additionally_matched,
        }

        # Update matcher stats after semantic matching
        final_matched = sum(1 for i in matched_items if i.get("product_id"))
        pipeline_stats["matcher"]["matched"] = final_matched
        pipeline_stats["matcher"]["unmatched"] = len(matched_items) - final_matched

        # Step 7: Register image hash for future duplicate detection
        try:
            self.duplicate_detector.register_processed(image_bytes)
        except Exception as e:
            logger.warning(f"Failed to register image hash: {e}")

        # Build final result
        status = "success" if final_matched == len(matched_items) and items else "partial"

        return {
            "status": status,
            "pipeline": pipeline_stats,
            "duplicate_check": duplicate_result,
            "data": {
                "customer_name": parsed.get("customer_name"),
                "customer_phone": parsed.get("customer_phone"),
                "invoice_number": parsed.get("invoice_number"),
                "date": parsed.get("date"),
                "subtotal": parsed.get("subtotal", 0.0),
                "tax": parsed.get("tax", 0.0),
                "total_amount": parsed.get("total_amount", 0.0),
                "supplier_name": parsed.get("supplier_name"),
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
