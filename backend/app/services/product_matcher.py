"""Product Matcher — matches extracted product names to existing products in the database."""
from sqlalchemy.orm import Session
from sqlalchemy import func
from app.models.products import Product
import logging
import re

logger = logging.getLogger(__name__)


class ProductMatcher:
    """Matches OCR-extracted product names to products in the ERP database."""

    def __init__(self, db: Session):
        self.db = db

    def match_items(self, items: list[dict]) -> list[dict]:
        """Match extracted items to database products.

        For each item, attempts to find the best matching product by name.
        Adds product_id and match_confidence to each item.

        Args:
            items: List of extracted items with product_name field

        Returns:
            Items with added product_id and match info
        """
        all_products = self.db.query(Product).filter(Product.active_status == True).all()

        matched_items = []
        for item in items:
            product_name = item.get("product_name", "")
            match = self._find_best_match(product_name, all_products)

            matched_item = {**item}
            if match:
                matched_item["product_id"] = match["product"].product_id
                matched_item["matched_product_name"] = match["product"].product_name
                matched_item["match_confidence"] = match["score"]
                matched_item["match_method"] = match["method"]
                # Use product's selling price if no price was extracted
                if not item.get("unit_price") or item["unit_price"] == 0:
                    matched_item["unit_price"] = float(match["product"].selling_price)
            else:
                matched_item["product_id"] = None
                matched_item["matched_product_name"] = None
                matched_item["match_confidence"] = 0
                matched_item["match_method"] = "none"

            matched_items.append(matched_item)

        return matched_items

    def _find_best_match(self, query: str, products: list[Product]) -> dict | None:
        """Find the best matching product for a given query string."""
        if not query or not products:
            return None

        query_lower = self._normalize(query)
        best_match = None
        best_score = 0

        for product in products:
            product_name = self._normalize(product.product_name)

            # Exact match
            if query_lower == product_name:
                return {"product": product, "score": 1.0, "method": "exact"}

            # Contains match
            if query_lower in product_name or product_name in query_lower:
                score = 0.8
                if score > best_score:
                    best_score = score
                    best_match = {"product": product, "score": score, "method": "contains"}
                continue

            # Word overlap match
            query_words = set(query_lower.split())
            product_words = set(product_name.split())
            if query_words and product_words:
                overlap = len(query_words & product_words)
                total = max(len(query_words), len(product_words))
                score = overlap / total * 0.7
                if score > best_score and score > 0.3:
                    best_score = score
                    best_match = {"product": product, "score": score, "method": "word_overlap"}

            # Barcode match (if query looks like a barcode)
            if product.barcode and query.strip() == product.barcode:
                return {"product": product, "score": 1.0, "method": "barcode"}

        return best_match if best_score > 0.3 else None

    def _normalize(self, text: str) -> str:
        """Normalize text for comparison."""
        # Remove diacritics and normalize Arabic
        text = text.strip().lower()
        # Remove common Arabic prefixes/suffixes
        text = re.sub(r'[ً-ٰٟ]', '', text)  # Remove tashkeel
        # Normalize alef variants
        text = text.replace('أ', 'ا').replace('إ', 'ا').replace('آ', 'ا')
        # Normalize taa marbuta
        text = text.replace('ة', 'ه')
        return text
