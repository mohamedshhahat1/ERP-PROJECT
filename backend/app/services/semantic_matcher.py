"""Semantic Product Matcher using pgvector embeddings for fuzzy matching."""
from sqlalchemy.orm import Session
from sqlalchemy import text
from app.config import settings
import httpx
import logging
import json

logger = logging.getLogger(__name__)


class SemanticMatcher:
    """Uses vector embeddings + pgvector for semantic product matching.

    When exact/contains matching fails, this uses embeddings to find
    semantically similar products (e.g., 'رويال رمادي' matches 'Royal Gray Porcelain 60x60')
    """

    def __init__(self, db: Session):
        self.db = db
        self.api_key = settings.anthropic_api_key

    def find_similar_products(self, query: str, limit: int = 3) -> list[dict]:
        """Find products semantically similar to the query text.

        Uses pgvector cosine similarity search on product embeddings.
        Falls back to basic ILIKE search if embeddings aren't available.
        """
        # Try pgvector semantic search first
        try:
            results = self._vector_search(query, limit)
            if results:
                return results
        except Exception as e:
            logger.debug(f"Vector search unavailable: {e}")

        # Fallback: fuzzy text search
        return self._fuzzy_search(query, limit)

    def _vector_search(self, query: str, limit: int) -> list[dict]:
        """Search using pgvector cosine similarity."""
        # Generate embedding for query
        embedding = self._get_embedding(query)
        if not embedding:
            return []

        # Search against product embeddings in ai_embeddings table
        sql = text("""
            SELECT ae.source_id as product_id, ae.source_text,
                   1 - (ae.embedding <=> :query_embedding::vector) as similarity
            FROM ai_embeddings ae
            WHERE ae.source_type = 'product'
            ORDER BY ae.embedding <=> :query_embedding::vector
            LIMIT :limit
        """)

        rows = self.db.execute(sql, {
            "query_embedding": str(embedding),
            "limit": limit,
        }).fetchall()

        return [
            {
                "product_id": row.product_id,
                "product_name": row.source_text,
                "similarity": round(float(row.similarity), 3),
                "method": "vector_search",
            }
            for row in rows
            if row.similarity > 0.5
        ]

    def _fuzzy_search(self, query: str, limit: int) -> list[dict]:
        """Fallback fuzzy text search using trigram similarity."""
        # Simple ILIKE with % wildcards
        sql = text("""
            SELECT product_id, product_name, selling_price
            FROM products
            WHERE active_status = TRUE
              AND (product_name ILIKE :q1 OR product_name ILIKE :q2)
            LIMIT :limit
        """)

        # Split query into words and search for any
        words = query.strip().split()
        q1 = f"%{query}%"
        q2 = f"%{words[0]}%" if words else f"%{query}%"

        rows = self.db.execute(sql, {"q1": q1, "q2": q2, "limit": limit}).fetchall()

        return [
            {
                "product_id": row.product_id,
                "product_name": row.product_name,
                "similarity": 0.6,
                "method": "fuzzy_search",
            }
            for row in rows
        ]

    def _get_embedding(self, text: str) -> list[float] | None:
        """Generate embedding using Anthropic's embedding-compatible endpoint.

        Note: If Anthropic embeddings aren't available, could use OpenAI or
        a local model. For now, returns None to trigger fallback.
        """
        # Anthropic doesn't have a public embeddings API yet.
        # Use OpenAI embeddings if key available, or return None for fallback.
        try:
            import openai
            if not settings.openai_api_key:
                return None
            client = openai.OpenAI(api_key=settings.openai_api_key)
            response = client.embeddings.create(
                input=text,
                model="text-embedding-3-small",
            )
            return response.data[0].embedding
        except Exception:
            return None
