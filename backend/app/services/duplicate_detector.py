"""Smart Duplicate Detection — detects if an invoice photo has already been processed."""
import hashlib
from sqlalchemy.orm import Session
from sqlalchemy import text
from app.core.redis import get_redis
from app.services.cache_service import CacheService
import json
import logging

logger = logging.getLogger(__name__)

DUPLICATE_KEY_PREFIX = "smart_invoice:hash:"
DUPLICATE_TTL = 86400 * 7  # 7 days


class DuplicateDetector:
    """Detects duplicate invoice uploads using image hashing and content similarity."""

    def __init__(self, db: Session):
        self.db = db
        self.redis = get_redis()

    def check_duplicate(self, image_bytes: bytes, extracted_data: dict | None = None) -> dict:
        """Check if this image or similar content has been processed before.

        Uses two strategies:
        1. Image hash — exact same photo uploaded twice
        2. Content similarity — same items/amounts but different photo

        Returns:
            {
                "is_duplicate": bool,
                "duplicate_type": "exact_image" | "similar_content" | None,
                "original_hash": str,
                "message": str | None,
                "matched_invoice_id": int | None,
            }
        """
        # Strategy 1: Image hash (perceptual hash using file content)
        image_hash = self._compute_hash(image_bytes)
        existing = self.redis.get(f"{DUPLICATE_KEY_PREFIX}{image_hash}")

        if existing:
            data = json.loads(existing)
            return {
                "is_duplicate": True,
                "duplicate_type": "exact_image",
                "original_hash": image_hash,
                "message": "يبدو أن هذه الصورة تم رفعها من قبل",
                "matched_invoice_id": data.get("invoice_id"),
                "original_timestamp": data.get("timestamp"),
            }

        # Strategy 2: Content similarity (if we have extracted data)
        if extracted_data and extracted_data.get("items"):
            content_match = self._check_content_similarity(extracted_data)
            if content_match:
                return {
                    "is_duplicate": True,
                    "duplicate_type": "similar_content",
                    "original_hash": image_hash,
                    "message": "يبدو أن هذه الفاتورة مسجلة بالفعل (نفس الأصناف والمبالغ)",
                    "matched_invoice_id": content_match.get("invoice_id"),
                }

        return {
            "is_duplicate": False,
            "duplicate_type": None,
            "original_hash": image_hash,
            "message": None,
            "matched_invoice_id": None,
        }

    def register_processed(self, image_bytes: bytes, invoice_id: int | None = None):
        """Register a successfully processed image to detect future duplicates."""
        image_hash = self._compute_hash(image_bytes)
        import datetime
        data = json.dumps({
            "invoice_id": invoice_id,
            "timestamp": datetime.datetime.now().isoformat(),
        })
        self.redis.set(f"{DUPLICATE_KEY_PREFIX}{image_hash}", data, ttl=DUPLICATE_TTL)

    def _compute_hash(self, image_bytes: bytes) -> str:
        """Compute a hash of the image content."""
        return hashlib.sha256(image_bytes).hexdigest()[:16]

    def _check_content_similarity(self, extracted_data: dict) -> dict | None:
        """Check if similar content exists in recent invoices."""
        items = extracted_data.get("items", [])
        if not items:
            return None

        # Build a content fingerprint from items
        total_amount = sum(
            (item.get("quantity", 0) or 0) * (item.get("unit_price", 0) or 0)
            for item in items
        )
        item_count = len(items)
        customer = extracted_data.get("customer_name", "")

        if total_amount == 0:
            return None

        # Search recent invoices with similar total (within 5% tolerance)
        tolerance = total_amount * 0.05
        sql = text("""
            SELECT invoice_id, invoice_number, total_amount, invoice_date
            FROM sales_invoices
            WHERE total_amount BETWEEN :min_total AND :max_total
              AND invoice_date >= CURRENT_DATE - INTERVAL '7 days'
            ORDER BY invoice_date DESC
            LIMIT 3
        """)

        rows = self.db.execute(sql, {
            "min_total": total_amount - tolerance,
            "max_total": total_amount + tolerance,
        }).fetchall()

        if rows:
            # Return the most likely match
            return {
                "invoice_id": rows[0].invoice_id,
                "invoice_number": rows[0].invoice_number,
                "total_amount": float(rows[0].total_amount),
            }

        return None
