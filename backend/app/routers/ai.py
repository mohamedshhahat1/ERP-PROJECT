from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session
from pydantic import BaseModel, Field
from app.database import get_db
from app.core.deps import get_current_user
from app.core.redis import get_redis
from app.models.users import User
from app.services.ai_service import AIService
from app.ai.claude_client import ClaudeClient
from app.ai.safety.permissions import AIPermissionChecker, AIPermissionDenied
import time
import logging

router = APIRouter()
logger = logging.getLogger(__name__)

# --- Rate Limiting ---
# Max AI requests per user per minute
AI_RATE_LIMIT = 20
AI_RATE_WINDOW = 60  # seconds


def _check_rate_limit(user_id: int):
    """Simple sliding-window rate limiter using Redis."""
    redis = get_redis()
    key = f"ai:rate:{user_id}"
    current = redis.get(key)
    if current and int(current) >= AI_RATE_LIMIT:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Rate limit exceeded. Maximum {AI_RATE_LIMIT} AI requests per minute.",
        )
    pipe = redis.pipeline()
    pipe.incr(key)
    pipe.expire(key, AI_RATE_WINDOW)
    pipe.execute()


def _validate_session_ownership(session_id: str, user_id: int):
    """Validate that a session ID belongs to the requesting user.

    Session IDs are formatted as 'session-{timestamp}' on the client.
    We enforce ownership by prefixing with user_id on storage.
    For backward compatibility, we also accept sessions that start with
    the user's ID prefix.
    """
    # Session IDs should be scoped to the user
    # Format: "{user_id}-{rest}" or "session-{timestamp}" (legacy)
    # We'll check if session data exists and belongs to this user via Redis
    redis = get_redis()
    owner_key = f"ai:session_owner:{session_id}"
    stored_owner = redis.get(owner_key)
    if stored_owner is not None:
        if int(stored_owner) != user_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied: this conversation belongs to another user.",
            )
    else:
        # First access — claim ownership
        redis.set(owner_key, str(user_id), ex=86400)  # 24h TTL


class ToolRequest(BaseModel):
    agent: str
    tool: str
    params: dict = {}


class ChatRequest(BaseModel):
    session_id: str = Field(..., max_length=100)
    message: str = Field(..., max_length=10000)


# --- CHAT (Claude Sonnet) ---

@router.post("/chat")
def ai_chat(data: ChatRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    _check_rate_limit(current_user.user_id)
    _validate_session_ownership(data.session_id, current_user.user_id)
    client = ClaudeClient(db, user_role=current_user.role)
    response = client.chat(data.session_id, data.message)
    return {"response": response, "session_id": data.session_id}


@router.post("/chat/stream")
def ai_chat_stream(data: ChatRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    _check_rate_limit(current_user.user_id)
    _validate_session_ownership(data.session_id, current_user.user_id)
    client = ClaudeClient(db, user_role=current_user.role)
    return StreamingResponse(
        client.chat_stream(data.session_id, data.message),
        media_type="text/event-stream",
    )


# --- TOOL EXECUTION ---

@router.post("/tool")
def execute_ai_tool(data: ToolRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Execute an AI tool with role-based permission enforcement."""
    # Enforce permission check BEFORE execution
    permission_checker = AIPermissionChecker(user_role=current_user.role)
    try:
        permission_checker.check_or_raise(data.tool)
    except AIPermissionDenied as e:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=str(e),
        )

    # Check amount limits if params contain an amount field
    amount = data.params.get("amount") or data.params.get("total_amount") or data.params.get("paid_amount")
    if amount is not None:
        try:
            permission_checker.check_amount(data.tool, float(amount))
        except AIPermissionDenied as e:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=str(e),
            )

    service = AIService(db)
    return service.execute_tool(data.agent, data.tool, data.params)


@router.post("/query")
def ai_query(data: ChatRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    service = AIService(db)
    routing = service.classify_and_route(data.message)
    context = service.search_context(data.message)
    return {"routing": routing, "context": context, "session_id": data.session_id}


# --- AGENTS ---

@router.get("/agents")
def list_agents(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    service = AIService(db)
    return {
        agent_type: {"tools": agent.get_tools_schema(), "description": agent.system_prompt.split("\n")[0]}
        for agent_type, agent in service.agents.items()
    }


# --- PREDICTIONS ---

@router.get("/predict/demand/{product_id}")
def predict_demand(product_id: int, days_back: int = 30, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    service = AIService(db)
    return service.demand_forecast(product_id, days_back)


@router.get("/predict/low-stock")
def predict_low_stock(days_ahead: int = 7, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    service = AIService(db)
    return service.low_stock_prediction(days_ahead)


@router.get("/predict/trending")
def predict_trending(days_back: int = 30, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    service = AIService(db)
    return service.best_selling_prediction(days_back)


@router.get("/predict/customer/{customer_id}")
def predict_customer(customer_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    service = AIService(db)
    return service.customer_behavior(customer_id)


@router.get("/analyze/profit")
def analyze_profit(start_date: str, end_date: str, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    service = AIService(db)
    return service.profit_analysis(start_date, end_date)


# --- SEARCH / RAG ---

@router.get("/search")
def ai_search(query: str, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    service = AIService(db)
    return service.search_context(query)


# --- CONVERSATION MEMORY ---

@router.get("/conversation/{session_id}")
def get_conversation(session_id: str, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    _validate_session_ownership(session_id, current_user.user_id)
    service = AIService(db)
    return {"messages": service.get_conversation(session_id)}


@router.delete("/conversation/{session_id}")
def clear_conversation(session_id: str, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    _validate_session_ownership(session_id, current_user.user_id)
    service = AIService(db)
    service.clear_conversation(session_id)
    return {"detail": "Conversation cleared"}
