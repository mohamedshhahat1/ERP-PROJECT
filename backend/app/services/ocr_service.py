"""OCR Service using PaddleOCR for Arabic/English text extraction from images."""
import numpy as np
from PIL import Image
import io
import logging

logger = logging.getLogger(__name__)


class OCRService:
    """Extracts text from images using PaddleOCR with Arabic support."""

    _instance = None
    _ocr = None

    @classmethod
    def get_instance(cls):
        """Singleton pattern — PaddleOCR model loads once and is reused."""
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance

    def __init__(self):
        self._load_model()

    def _load_model(self):
        """Load PaddleOCR model with Arabic + English support."""
        try:
            from paddleocr import PaddleOCR
            self._ocr = PaddleOCR(
                use_angle_cls=True,
                lang='ar',  # Arabic language support
                use_gpu=False,  # CPU mode for Docker compatibility
                show_log=False,
                det_db_thresh=0.3,
                rec_batch_num=6,
            )
            logger.info("PaddleOCR model loaded successfully (Arabic mode)")
        except ImportError:
            logger.warning("PaddleOCR not installed. Install with: pip install paddlepaddle paddleocr")
            self._ocr = None
        except Exception as e:
            logger.error(f"Failed to load PaddleOCR model: {e}")
            self._ocr = None

    def extract_text(self, image_bytes: bytes) -> dict:
        """Extract text from image bytes.

        Returns:
            {
                "raw_text": str,  # Full extracted text (line by line)
                "lines": [{"text": str, "confidence": float, "bbox": list}],
                "language_detected": str,
                "success": bool,
                "error": str | None
            }
        """
        if self._ocr is None:
            return {
                "raw_text": "",
                "lines": [],
                "language_detected": "unknown",
                "success": False,
                "error": "OCR engine not available. Install paddlepaddle and paddleocr.",
            }

        try:
            # Convert bytes to numpy array for PaddleOCR
            image = Image.open(io.BytesIO(image_bytes))
            img_array = np.array(image)

            # Run OCR
            results = self._ocr.ocr(img_array, cls=True)

            if not results or not results[0]:
                return {
                    "raw_text": "",
                    "lines": [],
                    "language_detected": "unknown",
                    "success": True,
                    "error": "No text detected in image",
                }

            # Parse results
            lines = []
            raw_lines = []

            for line in results[0]:
                bbox = line[0]  # [[x1,y1], [x2,y2], [x3,y3], [x4,y4]]
                text = line[1][0]  # Extracted text
                confidence = float(line[1][1])  # Confidence score

                lines.append({
                    "text": text,
                    "confidence": confidence,
                    "bbox": bbox,
                })
                raw_lines.append(text)

            # Sort lines by vertical position (top to bottom)
            lines.sort(key=lambda l: l["bbox"][0][1])

            raw_text = "\n".join([l["text"] for l in lines])

            # Detect primary language
            arabic_chars = sum(1 for c in raw_text if '؀' <= c <= 'ۿ')
            total_chars = len(raw_text.replace(" ", "").replace("\n", ""))
            language = "ar" if arabic_chars > total_chars * 0.3 else "en"

            return {
                "raw_text": raw_text,
                "lines": lines,
                "language_detected": language,
                "success": True,
                "error": None,
            }

        except Exception as e:
            logger.error(f"OCR extraction failed: {e}")
            return {
                "raw_text": "",
                "lines": [],
                "language_detected": "unknown",
                "success": False,
                "error": f"OCR processing failed: {str(e)}",
            }

    def extract_text_with_regions(self, image_bytes: bytes) -> dict:
        """Extract text with spatial awareness (useful for table-like documents)."""
        result = self.extract_text(image_bytes)
        if not result["success"] or not result["lines"]:
            return result

        # Group lines by vertical proximity (rows in a table)
        rows = []
        current_row = []
        last_y = None
        threshold = 20  # pixels

        for line in result["lines"]:
            y = line["bbox"][0][1]
            if last_y is None or abs(y - last_y) < threshold:
                current_row.append(line)
            else:
                if current_row:
                    rows.append(current_row)
                current_row = [line]
            last_y = y

        if current_row:
            rows.append(current_row)

        # Sort items within each row by x position (left to right)
        for row in rows:
            row.sort(key=lambda l: l["bbox"][0][0])

        result["rows"] = rows
        result["row_count"] = len(rows)
        return result
