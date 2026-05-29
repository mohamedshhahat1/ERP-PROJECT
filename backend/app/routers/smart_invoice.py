import base64
from fastapi import APIRouter, Depends, UploadFile, File, Form, HTTPException
from sqlalchemy.orm import Session
from app.database import get_db
from app.core.deps import require_permission
from app.models.users import User
from app.config import settings
import anthropic
import json
import logging

router = APIRouter()
logger = logging.getLogger(__name__)

EXTRACTION_PROMPT = """You are an invoice data extraction assistant for a ceramic/tile showroom ERP.

Analyze this image of a handwritten or printed order/invoice and extract all items with their details.

Return a JSON object with this exact structure:
{
  "customer_name": "extracted customer name or null if not visible",
  "items": [
    {
      "product_name": "product description as written",
      "quantity": 10.0,
      "unit_type": "meter" or "piece" or "carton",
      "unit_price": 150.0,
      "notes": "any additional notes for this item"
    }
  ],
  "notes": "any general notes from the document",
  "confidence": "high" or "medium" or "low"
}

Rules:
- Extract ALL items visible in the image
- If quantity is unclear, estimate and set confidence to "low"
- unit_type should be "meter" for مترات/meters, "piece" for قطع/pieces, "carton" for كراتين/cartons
- Prices should be numeric (no currency symbols)
- If Arabic text, translate product names to a recognizable format
- If you cannot read the image clearly, still extract what you can and set confidence accordingly
- Return ONLY the JSON, no markdown or explanation
"""


@router.post("/extract")
async def extract_invoice_from_image(
    file: UploadFile = File(...),
    language: str = Form(default="ar"),
    current_user: User = Depends(require_permission("sales:write")),
):
    """Extract invoice data from an uploaded image using Claude Vision."""
    if not settings.anthropic_api_key:
        raise HTTPException(status_code=503, detail="AI service not configured (ANTHROPIC_API_KEY missing)")

    # Read and encode the image
    image_data = await file.read()
    if len(image_data) > 20 * 1024 * 1024:  # 20MB limit
        raise HTTPException(status_code=413, detail="Image too large. Maximum 20MB.")

    # Determine media type
    content_type = file.content_type or "image/jpeg"
    if content_type not in ("image/jpeg", "image/png", "image/gif", "image/webp"):
        raise HTTPException(status_code=400, detail="Unsupported image format. Use JPEG, PNG, GIF, or WebP.")

    image_b64 = base64.b64encode(image_data).decode("utf-8")

    try:
        client = anthropic.Anthropic(api_key=settings.anthropic_api_key)
        response = client.messages.create(
            model=settings.ai_model,
            max_tokens=2000,
            messages=[
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "image",
                            "source": {
                                "type": "base64",
                                "media_type": content_type,
                                "data": image_b64,
                            },
                        },
                        {
                            "type": "text",
                            "text": EXTRACTION_PROMPT,
                        },
                    ],
                }
            ],
        )

        # Parse the response
        result_text = response.content[0].text.strip()
        # Remove markdown code fences if present
        if result_text.startswith("```"):
            result_text = result_text.split("\n", 1)[1]
            if result_text.endswith("```"):
                result_text = result_text[:-3].strip()

        extracted = json.loads(result_text)

        return {
            "status": "success",
            "data": extracted,
            "tokens_used": response.usage.input_tokens + response.usage.output_tokens,
        }

    except json.JSONDecodeError:
        logger.error(f"Failed to parse AI response as JSON: {result_text[:200]}")
        return {
            "status": "partial",
            "data": {"customer_name": None, "items": [], "notes": "Could not parse response", "confidence": "low"},
            "raw_response": result_text[:500],
        }
    except anthropic.APIError as e:
        logger.error(f"Anthropic API error: {e}")
        raise HTTPException(status_code=502, detail=f"AI service error: {str(e)}")
    except Exception as e:
        logger.error(f"Smart invoice extraction error: {e}")
        raise HTTPException(status_code=500, detail="Failed to process image")
