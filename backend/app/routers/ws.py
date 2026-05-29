from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Depends, Query
from app.core.websocket import get_ws_manager
from app.core.security import decode_access_token
import json
import logging

router = APIRouter()
logger = logging.getLogger(__name__)


@router.websocket("/ws/dashboard")
async def ws_dashboard(websocket: WebSocket, token: str = Query(None)):
    user_id = _verify_token(token)
    if not user_id:
        await websocket.close(code=4001)
        return

    mgr = get_ws_manager()
    await mgr.connect(websocket, "dashboard", user_id)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        pass
    except Exception as e:
        logger.warning(f"WebSocket dashboard error for user {user_id}: {e}")
    finally:
        mgr.disconnect(websocket, "dashboard", user_id)


@router.websocket("/ws/notifications")
async def ws_notifications(websocket: WebSocket, token: str = Query(None)):
    user_id = _verify_token(token)
    if not user_id:
        await websocket.close(code=4001)
        return

    mgr = get_ws_manager()
    await mgr.connect(websocket, "notifications", user_id)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        pass
    except Exception as e:
        logger.warning(f"WebSocket notifications error for user {user_id}: {e}")
    finally:
        mgr.disconnect(websocket, "notifications", user_id)


@router.websocket("/ws/inventory")
async def ws_inventory(websocket: WebSocket, token: str = Query(None)):
    user_id = _verify_token(token)
    if not user_id:
        await websocket.close(code=4001)
        return

    mgr = get_ws_manager()
    await mgr.connect(websocket, "inventory", user_id)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        pass
    except Exception as e:
        logger.warning(f"WebSocket inventory error for user {user_id}: {e}")
    finally:
        mgr.disconnect(websocket, "inventory", user_id)


@router.websocket("/ws/ai")
async def ws_ai_stream(websocket: WebSocket, token: str = Query(None)):
    user_id = _verify_token(token)
    if not user_id:
        await websocket.close(code=4001)
        return

    mgr = get_ws_manager()
    await mgr.connect(websocket, "ai", user_id)
    try:
        while True:
            data = await websocket.receive_text()
            try:
                message = json.loads(data)
            except json.JSONDecodeError:
                await websocket.send_text(json.dumps({"type": "error", "detail": "Invalid JSON"}))
                continue
            # Stream AI response back token by token
            await _stream_ai_response(websocket, user_id, message)
    except WebSocketDisconnect:
        pass
    except Exception as e:
        logger.warning(f"WebSocket AI error for user {user_id}: {e}")
    finally:
        mgr.disconnect(websocket, "ai", user_id)


async def _stream_ai_response(websocket: WebSocket, user_id: int, message: dict):
    """Stream AI response via WebSocket using ClaudeClient."""
    from app.database import SessionLocal
    from app.ai.claude_client import ClaudeClient

    query = message.get("query", "")
    session_id = message.get("session_id", f"ws-{user_id}")

    if not query:
        await websocket.send_text(json.dumps({"type": "error", "detail": "No query provided"}))
        return

    await websocket.send_text(json.dumps({"type": "ai_start", "query": query}))

    try:
        db = SessionLocal()
        try:
            client = ClaudeClient(db, user_role=message.get("role", "ai_agent"))
            full_response = ""
            async for chunk in client.chat_stream(session_id, query):
                # chunk is a JSON string from SSE
                if isinstance(chunk, str):
                    await websocket.send_text(json.dumps({"type": "ai_token", "text": chunk}))
                    full_response += chunk
            await websocket.send_text(json.dumps({"type": "ai_end", "full_response": full_response}))
        finally:
            db.close()
    except Exception as e:
        logger.error(f"AI WebSocket streaming error: {e}")
        await websocket.send_text(json.dumps({"type": "ai_end", "full_response": "حصل خطأ أثناء المعالجة. حاول مرة أخرى."}))


def _verify_token(token: str | None) -> int | None:
    if not token:
        return None
    payload = decode_access_token(token)
    if not payload:
        return None
    return int(payload.get("sub", 0))
