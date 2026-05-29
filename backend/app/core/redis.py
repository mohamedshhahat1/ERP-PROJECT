import redis
import json
from decimal import Decimal
from app.config import settings


class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            return str(obj)
        return super().default(obj)


class RedisClient:
    def __init__(self):
        self._client = redis.from_url(settings.redis_url, decode_responses=True)

    @property
    def client(self):
        return self._client

    def get(self, key: str) -> str | None:
        return self._client.get(key)

    def getdel(self, key: str) -> str | None:
        return self._client.getdel(key)

    def set(self, key: str, value: str, ttl: int | None = None, ex: int | None = None):
        timeout = ttl or ex
        if timeout:
            self._client.setex(key, timeout, value)
        else:
            self._client.set(key, value)

    def delete(self, key: str):
        self._client.delete(key)

    def get_json(self, key: str) -> dict | list | None:
        data = self._client.get(key)
        if data:
            return json.loads(data)
        return None

    def set_json(self, key: str, value: dict | list, ttl: int | None = None):
        data = json.dumps(value, cls=DecimalEncoder)
        self.set(key, data, ttl)

    def delete_pattern(self, pattern: str):
        """Delete keys matching pattern using SCAN (non-blocking, production-safe)."""
        cursor = 0
        while True:
            cursor, keys = self._client.scan(cursor, match=pattern, count=100)
            if keys:
                self._client.delete(*keys)
            if cursor == 0:
                break

    def incr(self, key: str) -> int:
        return self._client.incr(key)

    def expire(self, key: str, ttl: int):
        self._client.expire(key, ttl)

    def pipeline(self):
        return self._client.pipeline()

    def smembers(self, key: str) -> set:
        return self._client.smembers(key)

    def ping(self) -> bool:
        try:
            return self._client.ping()
        except redis.ConnectionError:
            return False


redis_client = RedisClient()


def get_redis() -> RedisClient:
    return redis_client
