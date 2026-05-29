from app.celery_app import celery_app
from app.database import SessionLocal
from app.core.redis import get_redis
from app.services.cache_service import CacheService
import logging

logger = logging.getLogger(__name__)


@celery_app.task(name="app.tasks.ai.process_ai_query")
def process_ai_query(session_id: str, query: str, user_role: str = "ai_agent"):
    """Process an AI query asynchronously via Celery (for background/batch operations)."""
    db = SessionLocal()
    try:
        from app.ai.claude_client import ClaudeClient
        client = ClaudeClient(db, user_role=user_role)
        response = client.chat(session_id, query)
        return {"status": "success", "session_id": session_id, "response": response}
    except Exception as e:
        logger.error(f"AI task error: {e}")
        return {"status": "error", "session_id": session_id, "detail": str(e)}
    finally:
        db.close()


@celery_app.task(name="app.tasks.ai.train_embeddings")
def train_embeddings():
    """Generate/refresh vector embeddings for products, customers, and suppliers."""
    db = SessionLocal()
    try:
        from app.ai.embeddings.service import EmbeddingService
        service = EmbeddingService(db)
        result = service.refresh_all_embeddings()
        return {"status": "success", "detail": result}
    except Exception as e:
        logger.error(f"Embedding training error: {e}")
        return {"status": "error", "detail": str(e)}
    finally:
        db.close()
