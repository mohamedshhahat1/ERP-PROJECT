"""Invoice Parser — uses Claude AI to structure raw OCR text into invoice data."""
import json
import logging
from app.config import settings
import anthropic

logger = logging.getLogger(__name__)

PARSER_PROMPT = """You are an invoice data parser for a ceramic/tile showroom ERP system.

I will give you raw OCR text extracted from a handwritten or printed order/invoice.
Your job is to structure this text into a JSON invoice.

OCR TEXT:
---
{ocr_text}
---

ADDITIONAL CONTEXT:
- This is for a ceramic and tile showroom in Egypt
- Prices are in Egyptian Pounds (EGP)
- Common units: متر (meter), قطعة (piece), كرتونة (carton)
- Product names may include: سيراميك, بورسلين, جرانيت, رخام, لاصق, جراوت
- Customer names are typically Arabic names
- Numbers may be written in Arabic (٠١٢٣٤٥٦٧٨٩) or English digits

Return ONLY a valid JSON object with this structure:
{{
  "customer_name": "extracted customer name or null",
  "customer_phone": "phone number if visible or null",
  "invoice_number": "extracted invoice number or null",
  "date": "extracted date in YYYY-MM-DD format or null",
  "subtotal": 0.0,
  "tax": 0.0,
  "total_amount": 0.0,
  "supplier_name": "if this is a purchase invoice, supplier name or null",
  "items": [
    {{
      "product_name": "product description",
      "quantity": 10.0,
      "unit_type": "meter|piece|carton",
      "unit_price": 150.0,
      "confidence": 0.95,
      "notes": "any notes for this item or null"
    }}
  ],
  "discount": 0.0,
  "notes": "general notes or null",
  "payment_type": "cash|credit|mixed|unknown",
  "confidence": "high|medium|low",
  "parsing_notes": "any issues or assumptions made during parsing"
}}

Rules:
- Extract ALL items you can identify
- Convert Arabic numerals (٠-٩) to standard digits
- If quantity or price is unclear, estimate and note in parsing_notes
- unit_type: "meter" for متر/م, "piece" for قطعة/ق, "carton" for كرتونة/كرتون
- If a line looks like a total/subtotal, don't include it as an item
- Set confidence based on OCR text clarity
- Add a confidence score (0.0-1.0) for each item based on how clearly you could read it
- Look for totals/subtotals (إجمالي, مجموع, total) — extract as total_amount, not as line items
- Look for tax amounts (ضريبة, VAT, tax)
- Look for invoice/order numbers (رقم الفاتورة, #, No.)
- Look for dates in any format and convert to YYYY-MM-DD
- If it looks like a supplier/purchase invoice (has supplier name), set supplier_name
"""


class InvoiceParser:
    """Parses raw OCR text into structured invoice data using Claude AI."""

    def __init__(self):
        self.client = anthropic.Anthropic(api_key=settings.anthropic_api_key) if settings.anthropic_api_key else None
        self.model = settings.ai_model

    def parse(self, ocr_text: str, language: str = "ar") -> dict:
        """Parse OCR text into structured invoice data.

        Args:
            ocr_text: Raw text extracted by OCR
            language: Detected language of the text

        Returns:
            Structured invoice data dict
        """
        if not self.client:
            return {
                "error": "AI service not configured (ANTHROPIC_API_KEY missing)",
                "customer_name": None,
                "items": [],
                "confidence": "low",
            }

        if not ocr_text or not ocr_text.strip():
            return {
                "error": "No text to parse",
                "customer_name": None,
                "items": [],
                "confidence": "low",
            }

        try:
            prompt = PARSER_PROMPT.format(ocr_text=ocr_text)

            response = self.client.messages.create(
                model=self.model,
                max_tokens=2000,
                messages=[{"role": "user", "content": prompt}],
            )

            result_text = response.content[0].text.strip()

            # Remove markdown fences if present
            if result_text.startswith("```"):
                result_text = result_text.split("\n", 1)[1]
                if result_text.endswith("```"):
                    result_text = result_text[:-3].strip()
                elif "```" in result_text:
                    result_text = result_text[:result_text.rfind("```")].strip()

            parsed = json.loads(result_text)
            parsed["tokens_used"] = response.usage.input_tokens + response.usage.output_tokens
            return parsed

        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse AI response as JSON: {e}")
            return {
                "error": "Failed to parse AI response",
                "raw_response": result_text[:500] if 'result_text' in dir() else "",
                "customer_name": None,
                "items": [],
                "confidence": "low",
            }
        except anthropic.APIError as e:
            logger.error(f"Anthropic API error in invoice parser: {e}")
            return {
                "error": f"AI service error: {str(e)}",
                "customer_name": None,
                "items": [],
                "confidence": "low",
            }
        except Exception as e:
            logger.error(f"Invoice parsing error: {e}")
            return {
                "error": f"Parsing failed: {str(e)}",
                "customer_name": None,
                "items": [],
                "confidence": "low",
            }
