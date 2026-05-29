"""Quantity Normalizer — handles various Arabic/English quantity formats in ceramic business."""
import re
import logging

logger = logging.getLogger(__name__)

# Arabic number words
ARABIC_NUMBERS = {
    'صفر': 0, 'واحد': 1, 'اثنين': 2, 'اتنين': 2, 'ثلاثة': 3, 'تلاتة': 3,
    'أربعة': 4, 'اربعة': 4, 'خمسة': 5, 'ستة': 6, 'سبعة': 7, 'ثمانية': 8, 'تمانية': 8,
    'تسعة': 9, 'عشرة': 10, 'عشر': 10,
    'عشرين': 20, 'ثلاثين': 30, 'تلاتين': 30, 'أربعين': 40, 'اربعين': 40,
    'خمسين': 50, 'ستين': 60, 'سبعين': 70, 'ثمانين': 80, 'تسعين': 90, 'مية': 100, 'مائة': 100,
    'ميتين': 200, 'مئتين': 200, 'ثلاثمية': 300, 'أربعمية': 400, 'خمسمية': 500,
    'ألف': 1000, 'الف': 1000,
}

# Arabic digit conversion
ARABIC_DIGITS = {'٠': '0', '١': '1', '٢': '2', '٣': '3', '٤': '4', '٥': '5', '٦': '6', '٧': '7', '٨': '8', '٩': '9'}

# Unit patterns (Arabic + English)
UNIT_PATTERNS = {
    'meter': [
        r'متر', r'م\b', r'مت', r'meter', r'meters', r'm\b', r'mtr',
        r'طولي', r'م\.ط', r'sq\.m', r'sqm',
    ],
    'piece': [
        r'قطعة', r'قطع', r'ق\b', r'حبة', r'حب', r'piece', r'pieces', r'pcs', r'pc',
    ],
    'carton': [
        r'كرتون', r'كرتونة', r'كراتين', r'كرت', r'carton', r'cartons', r'ctn', r'box', r'boxes',
    ],
}


class QuantityNormalizer:
    """Normalizes various quantity formats commonly used in ceramic/tile business."""

    def normalize_quantity(self, text: str) -> dict:
        """Parse a quantity string and extract numeric value + unit.

        Handles:
        - "50 م", "50 متر", "50m", "خمسين متر"
        - "٥٠ متر" (Arabic digits)
        - "20 قطعة", "20 pcs"
        - "5 كرتون", "5 ctn"
        - "نص كرتونة" (half carton)

        Returns:
            {"quantity": float, "unit_type": str, "confidence": float, "original": str}
        """
        original = text.strip()
        normalized = self._convert_arabic_digits(original)

        # Try numeric extraction first
        quantity = self._extract_number(normalized)
        unit = self._detect_unit(normalized)

        if quantity is not None:
            return {
                "quantity": quantity,
                "unit_type": unit,
                "confidence": 0.9 if quantity > 0 else 0.5,
                "original": original,
            }

        # Try Arabic word numbers
        quantity = self._parse_arabic_words(normalized)
        if quantity is not None:
            return {
                "quantity": quantity,
                "unit_type": unit,
                "confidence": 0.7,
                "original": original,
            }

        return {
            "quantity": 0,
            "unit_type": unit or "meter",
            "confidence": 0.2,
            "original": original,
        }

    def normalize_items(self, items: list[dict]) -> list[dict]:
        """Normalize quantities for all items in a list."""
        normalized = []
        for item in items:
            norm_item = {**item}

            # Try to normalize quantity if it seems like a string
            qty = item.get("quantity", 0)
            if isinstance(qty, str):
                result = self.normalize_quantity(qty)
                norm_item["quantity"] = result["quantity"]
                norm_item["unit_type"] = result["unit_type"] or item.get("unit_type", "meter")
                norm_item["quantity_confidence"] = result["confidence"]
            else:
                norm_item["quantity_confidence"] = 0.9

            # Normalize unit_type
            unit = norm_item.get("unit_type", "")
            norm_item["unit_type"] = self._standardize_unit(unit)

            normalized.append(norm_item)
        return normalized

    def _convert_arabic_digits(self, text: str) -> str:
        """Convert Arabic digits (٠-٩) to standard digits (0-9)."""
        for ar, en in ARABIC_DIGITS.items():
            text = text.replace(ar, en)
        return text

    def _extract_number(self, text: str) -> float | None:
        """Extract numeric value from text."""
        # Match decimal or integer numbers
        match = re.search(r'(\d+\.?\d*)', text)
        if match:
            return float(match.group(1))

        # Match fractions like "نص" (half)
        if 'نص' in text or 'نصف' in text:
            match = re.search(r'(\d+\.?\d*)', text)
            if match:
                return float(match.group(1)) + 0.5
            return 0.5

        return None

    def _parse_arabic_words(self, text: str) -> float | None:
        """Parse Arabic number words like 'خمسين' → 50."""
        text_lower = text.strip()

        # Direct lookup
        for word, value in ARABIC_NUMBERS.items():
            if word in text_lower:
                return float(value)

        # Compound numbers: "خمسة وعشرين" → 25
        if 'و' in text_lower:
            parts = text_lower.split('و')
            total = 0
            found = False
            for part in parts:
                part = part.strip()
                for word, value in ARABIC_NUMBERS.items():
                    if word in part:
                        total += value
                        found = True
                        break
            if found:
                return float(total)

        return None

    def _detect_unit(self, text: str) -> str:
        """Detect unit type from text."""
        text_lower = text.lower()
        for unit_type, patterns in UNIT_PATTERNS.items():
            for pattern in patterns:
                if re.search(pattern, text_lower):
                    return unit_type
        return "meter"  # Default for ceramic business

    def _standardize_unit(self, unit: str) -> str:
        """Standardize unit string to one of: meter, piece, carton."""
        unit_lower = unit.lower().strip()
        for standard, patterns in UNIT_PATTERNS.items():
            for pattern in patterns:
                if re.search(pattern, unit_lower):
                    return standard
        if unit_lower in ('meter', 'piece', 'carton'):
            return unit_lower
        return "meter"
