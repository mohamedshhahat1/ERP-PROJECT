from sqlalchemy.orm import Session
from app.ai.agents.manager_agent import ManagerAgent
from app.ai.executor import ToolExecutor
from app.ai.tools.reporting_tools import ReportingTools
from app.ai.tools.tool_schemas import TOOL_SCHEMAS
from app.ai.memory.conversation import ConversationMemory
from app.ai.rag.retriever import ERPContextRetriever
from app.core.redis import get_redis
from app.services.cache_service import CacheService
import json


class AIService:
    """Orchestrates AI agents, memory, RAG, and predictions."""

    def __init__(self, db: Session, user_role: str = "ai_agent"):
        self.db = db
        self.user_role = user_role
        self.cache = CacheService(get_redis())
        self.agents = {
            "manager": ManagerAgent(db, user_role=user_role),
        }
        self.reporting = ReportingTools(db)
        self.retriever = ERPContextRetriever(db)

    def get_agent(self, agent_type: str):
        return self.agents.get(agent_type)

    def execute_tool(self, agent_type: str, tool_name: str, params: dict) -> dict:
        """Execute a single AI tool directly (bypassing the LLM)."""
        executor = ToolExecutor(self.db, session_id="direct", user_role=self.user_role, channel="api")
        result = executor.execute(tool_name, params)
        try:
            return json.loads(result)
        except (json.JSONDecodeError, TypeError):
            return {"result": result}

    def classify_and_route(self, query: str) -> dict:
        """Use RAG to find relevant context for a query."""
        context = self.search_context(query)
        return {"query": query, "context": context}

    def get_tools_schema(self) -> list:
        """Return all available tool schemas."""
        return TOOL_SCHEMAS

    # --- PREDICTIONS ---

    def demand_forecast(self, product_id: int, days_back: int = 30) -> dict:
        return self.reporting.demand_forecast(product_id, days_back)

    def low_stock_prediction(self, days_ahead: int = 7) -> dict:
        return self.reporting.low_stock_prediction(days_ahead)

    def best_selling_prediction(self, days_back: int = 30) -> dict:
        return self.reporting.best_selling_prediction(days_back)

    def customer_behavior(self, customer_id: int) -> dict:
        return self.reporting.customer_behavior_analysis(customer_id)

    def profit_analysis(self, start_date: str, end_date: str) -> dict:
        return self.reporting.profit_analysis(start_date, end_date)

    # --- RAG ---

    def search_context(self, query: str) -> dict:
        return {
            "products": self.retriever.search_products(query),
            "customers": self.retriever.search_customers(query),
            "suppliers": self.retriever.search_suppliers(query),
        }

    # --- MEMORY ---

    def get_memory(self, session_id: str) -> ConversationMemory:
        return ConversationMemory(session_id)

    def get_conversation(self, session_id: str) -> list:
        return ConversationMemory(session_id).get_history()

    def clear_conversation(self, session_id: str):
        ConversationMemory(session_id).clear()
