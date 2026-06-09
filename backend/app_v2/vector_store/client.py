import logging

from qdrant_client import QdrantClient

from app_v2.config import settings

logger = logging.getLogger(__name__)


def create_qdrant_client() -> QdrantClient:
    logger.info(
        "Connecting to Qdrant at %s:%s...",
        settings.QDRANT_HOST,
        settings.QDRANT_PORT,
    )
    return QdrantClient(
        host=settings.QDRANT_HOST,
        port=settings.QDRANT_PORT,
    )


def verify_qdrant_connection(client: QdrantClient) -> None:
    try:
        client.get_collection(settings.QDRANT_COLLECTION_NAME)
    except Exception as exc:
        raise RuntimeError(
            f"Collection '{settings.QDRANT_COLLECTION_NAME}' not found. "
            f"Run the migration script first."
        ) from exc
    logger.info(
        "Qdrant connected — collection '%s' ready",
        settings.QDRANT_COLLECTION_NAME,
    )
