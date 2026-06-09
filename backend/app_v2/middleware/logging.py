import json as json_lib
import logging
import time
from typing import Callable
from uuid import uuid4

from fastapi import Request, Response
from starlette.middleware.base import BaseHTTPMiddleware

from app_v2.config import settings

SENSITIVE_PATHS = {"/auth/login", "/auth/refresh", "/register"}


class JSONFormatter(logging.Formatter):

    def format(self, record: logging.LogRecord) -> str:
        log_data = {
            "level": record.levelname,
            "timestamp": self.formatTime(record),
            "logger": record.name,
            "message": record.getMessage(),
        }
        if hasattr(record, "extra"):
            log_data.update(record.extra)
        if record.exc_info:
            log_data["traceback"] = self.formatException(record.exc_info)
        return json_lib.dumps(log_data)


class StepTimer:
    """Context manager for timing individual pipeline steps."""

    def __init__(self, step_name: str, request_id: str) -> None:
        self.step_name = step_name
        self.request_id = request_id
        self._start: float | None = None

    def __enter__(self) -> "StepTimer":
        self._start = time.time()
        return self

    def __exit__(self, *args: object) -> None:
        latency_ms = (time.time() - self._start) * 1000  # type: ignore[operator]
        logging.getLogger(__name__).info(
            "step_complete",
            extra={
                "step": self.step_name,
                "request_id": self.request_id,
                "latency_ms": round(latency_ms, 2),
            },
        )


def setup_logging() -> None:
    handler = logging.StreamHandler()
    handler.setFormatter(JSONFormatter())

    root = logging.getLogger()
    root.setLevel(logging.DEBUG if settings.DEBUG else logging.INFO)
    root.addHandler(handler)

    logging.getLogger("uvicorn.access").setLevel(logging.WARNING)
    logging.getLogger("httpx").setLevel(logging.WARNING)


class LoggingMiddleware(BaseHTTPMiddleware):

    async def dispatch(
        self,
        request: Request,
        call_next: Callable,
    ) -> Response:
        logger = logging.getLogger(__name__)
        request_id = str(uuid4())
        request.state.request_id = request_id
        start_time = time.time()

        path = request.url.path
        if path not in SENSITIVE_PATHS:
            logger.info(
                "request_in",
                extra={
                    "request_id": request_id,
                    "method": request.method,
                    "path": path,
                    "client_ip": request.client.host if request.client else "",
                    "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                },
            )

        success = False
        try:
            response = await call_next(request)
            success = True
        except Exception:
            logger.error(
                "unhandled_exception",
                extra={"request_id": request_id},
                exc_info=True,
            )
            raise
        finally:
            latency_ms = (time.time() - start_time) * 1000
            logger.info(
                "request_out",
                extra={
                    "request_id": request_id,
                    "method": request.method,
                    "path": path,
                    "status_code": getattr(response, "status_code", 500) if success else 500,
                    "latency_ms": round(latency_ms, 2),
                    "success": success,
                },
            )

        return response
