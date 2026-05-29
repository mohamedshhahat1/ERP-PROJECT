import secrets

from pydantic import field_validator
from pydantic_settings import BaseSettings

# Secrets that must never be used in production
_UNSAFE_SECRET_VALUES = {"change-me", "change-this-to-a-random-secret-key", "secret", ""}


class Settings(BaseSettings):
    database_url: str = "postgresql://postgres:password@localhost:5432/ceramic_erp"
    redis_url: str = "redis://localhost:6379/0"
    celery_broker_url: str = "redis://localhost:6379/1"
    celery_result_backend: str = "redis://localhost:6379/1"
    secret_key: str = ""
    access_token_expire_minutes: int = 480
    anthropic_api_key: str = ""
    ai_model: str = "claude-sonnet-4-20250514"
    openai_api_key: str = ""
    deepgram_api_key: str = ""
    elevenlabs_api_key: str = ""
    elevenlabs_voice_id: str = "21m00Tcm4TlvDq8ikWAM"
    debug: bool = False
    allowed_origins: str = "http://localhost:3000,http://localhost:5173"

    # Azure Speech (Egyptian Arabic TTS)
    azure_speech_key: str = ""
    azure_speech_region: str = "eastus"
    azure_tts_voice: str = "ar-EG-ShakirNeural"

    # AI Tool Permissions
    ai_can_write: bool = True
    ai_max_transaction: float = 50000
    ai_can_cancel_invoices: bool = True
    ai_can_refund: bool = True
    ai_max_refund: float = 50000
    ai_can_adjust_stock: bool = True
    ai_can_create_customers: bool = True

    # WhatsApp Integration (Meta Cloud API)
    whatsapp_api_token: str = ""
    whatsapp_phone_number_id: str = ""
    whatsapp_owner_phone: str = ""
    whatsapp_can_send: bool = False
    whatsapp_can_bulk_message: bool = False
    whatsapp_max_messages_per_request: int = 50

    @field_validator("secret_key", mode="before")
    @classmethod
    def validate_secret_key(cls, v: str) -> str:
        if v in _UNSAFE_SECRET_VALUES or len(v) < 32:
            import warnings
            warnings.warn(
                "SECRET_KEY is missing or insecure. Generating a random key for this session. "
                "Set a strong SECRET_KEY (≥32 chars) in your .env file for production.",
                stacklevel=2,
            )
            return secrets.token_urlsafe(64)
        return v

    @property
    def cors_origins(self) -> list[str]:
        return [o.strip() for o in self.allowed_origins.split(",") if o.strip()]

    class Config:
        env_file = ".env"


settings = Settings()
