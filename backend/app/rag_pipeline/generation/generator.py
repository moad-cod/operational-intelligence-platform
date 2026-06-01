from groq import Groq, GroqError

from app.core.config import settings
from app.core.logging import logger
from app.rag_pipeline.prompts.system_prompt import build_prompt


_client = None


def get_groq_client():
    global _client
    if _client is None:
        if not settings.groq_api_key:
            raise RuntimeError("GROQ_API_KEY is not set")
        _client = Groq(api_key=settings.groq_api_key)
        logger.info("Groq client initialized")
    return _client


def generate_response(context: str, query: str) -> str:
    if not context.strip():
        logger.warning("Empty context — generation may be poor")

    client = get_groq_client()
    messages = build_prompt(context, query)

    try:
        completion = client.chat.completions.create(
            model=settings.groq_model,
            messages=messages,
            temperature=settings.groq_temperature,
            max_tokens=settings.groq_max_tokens,
        )
        response = completion.choices[0].message.content
        logger.info("Groq generation complete (%d tokens estimated)", len(response) // 4)
        return response
    except GroqError as e:
        logger.error("Groq API error: %s", e)
        raise
