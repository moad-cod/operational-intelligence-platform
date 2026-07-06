import asyncio
import time
from typing import Callable

from fastapi import Request, Response
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware

from app_v2.config import settings
from app_v2.core.security import decode_token

RATE_LIMIT_RULES: dict[str, tuple[int, int]] = {
    "/search": (20, 60),
    "/auth/login": (5, 60),
    "/register": (3, 300),
    "default": (100, 60),
}


class RateLimitMiddleware(BaseHTTPMiddleware):

    def __init__(self, app: object) -> None:
        super().__init__(app)  # type: ignore[arg-type]
        self._store: dict[str, dict] = {}
        self._lock = asyncio.Lock()

    async def dispatch(
        self,
        request: Request,
        call_next: Callable,
    ) -> Response:
        if not settings.RATE_LIMIT_ENABLED:
            return await call_next(request)

        identifier = await self._get_identifier(request)
        max_requests, window_seconds = self._get_rule(request.url.path)
        allowed, retry_after = await self._check_limit(
            identifier, max_requests, window_seconds,
        )

        if not allowed:
            return JSONResponse(
                status_code=429,
                content={"detail": "Too many requests", "retry_after": retry_after},
                headers={"Retry-After": str(retry_after)},
            )

        return await call_next(request)

    async def _get_identifier(self, request: Request) -> str:
        auth = request.headers.get("Authorization", "")
        if auth.startswith("Bearer "):
            try:
                payload = decode_token(auth.split(" ", 1)[1])
                return f"user:{payload['sub']}"
            except Exception:
                pass
        ip = request.client.host if request.client else "unknown"
        return f"ip:{ip}"

    async def _check_limit(
        self,
        identifier: str,
        max_requests: int,
        window_seconds: int,
    ) -> tuple[bool, int]:
        async with self._lock:
            now = time.time()
            record = self._store.get(identifier)

            if record is None or (now - record["window_start"]) > window_seconds:
                self._store[identifier] = {"count": 1, "window_start": now}
                return True, 0

            if record["count"] >= max_requests:
                retry_after = int(window_seconds - (now - record["window_start"]))
                return False, max(retry_after, 1)

            record["count"] += 1
            return True, 0

    @staticmethod
    def _get_rule(path: str) -> tuple[int, int]:
        for prefix, rule in RATE_LIMIT_RULES.items():
            if prefix != "default" and path.startswith(prefix):
                return rule
        return RATE_LIMIT_RULES["default"]
