from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.config import settings
from app.core.exceptions import AppError
from app.core.middleware import app_error_handler
from app.events.registry import register_event_handlers
from app.routers import auth, products, categories, customers, suppliers, sales, purchases, inventory, payments, expenses, users, transfers, dashboard, tasks, ai, reports, notifications, embeddings, ws, insights, anomalies, opening_balances, voice, ai_audit, whatsapp, accounting, smart_invoice


@asynccontextmanager
async def lifespan(application: FastAPI):
    from app.database import Base, engine
    from app.core.logging_config import configure_logging
    import app.models  # noqa: F401 — ensure all models are registered
    configure_logging(debug=settings.debug)
    Base.metadata.create_all(bind=engine)
    register_event_handlers()
    yield


app = FastAPI(
    title="Ceramic Showroom ERP API",
    version="4.3.0",
    description="Adaptive intelligence ERP with Voice AI and anomaly detection",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.add_exception_handler(AppError, app_error_handler)

app.include_router(auth.router, prefix="/api/auth", tags=["Authentication"])
app.include_router(dashboard.router, prefix="/api/dashboard", tags=["Dashboard"])
app.include_router(insights.router, prefix="/api/insights", tags=["AI Insights"])
app.include_router(anomalies.router, prefix="/api/anomalies", tags=["Anomaly Detection"])
app.include_router(notifications.router, prefix="/api/notifications", tags=["Notifications"])
app.include_router(ai.router, prefix="/api/ai", tags=["AI Assistant"])
app.include_router(voice.router, prefix="/api/ai/voice", tags=["Voice AI"])
app.include_router(ai_audit.router, prefix="/api/admin/ai-audit", tags=["AI Audit Dashboard"])
app.include_router(embeddings.router, prefix="/api/embeddings", tags=["Embeddings"])
app.include_router(reports.router, prefix="/api/reports", tags=["Reports"])
app.include_router(whatsapp.router, prefix="/api/whatsapp", tags=["WhatsApp"])
app.include_router(categories.router, prefix="/api/categories", tags=["Categories"])
app.include_router(products.router, prefix="/api/products", tags=["Products"])
app.include_router(inventory.router, prefix="/api/inventory", tags=["Inventory"])
app.include_router(transfers.router, prefix="/api/transfers", tags=["Transfers"])
app.include_router(customers.router, prefix="/api/customers", tags=["Customers"])
app.include_router(suppliers.router, prefix="/api/suppliers", tags=["Suppliers"])
app.include_router(sales.router, prefix="/api/sales", tags=["Sales"])
app.include_router(purchases.router, prefix="/api/purchases", tags=["Purchases"])
app.include_router(payments.router, prefix="/api/payments", tags=["Payments"])
app.include_router(expenses.router, prefix="/api/expenses", tags=["Expenses"])
app.include_router(opening_balances.router, prefix="/api/opening-balances", tags=["Opening Balances"])
app.include_router(users.router, prefix="/api/users", tags=["Users"])
app.include_router(tasks.router, prefix="/api/tasks", tags=["Background Tasks"])
app.include_router(accounting.router, prefix="/api/accounting", tags=["Accounting"])
app.include_router(smart_invoice.router, prefix="/api/smart-invoice", tags=["Smart Invoice"])
app.include_router(ws.router, tags=["WebSocket"])


@app.get("/")
def root():
    return {"message": "Ceramic Showroom ERP API", "version": "4.3.0"}


@app.get("/health")
def health_check():
    """Basic health check — returns minimal status without infrastructure details."""
    from app.core.redis import get_redis
    try:
        redis_ok = get_redis().ping()
    except Exception:
        redis_ok = False
    status = "healthy" if redis_ok else "degraded"
    return {"status": status}
