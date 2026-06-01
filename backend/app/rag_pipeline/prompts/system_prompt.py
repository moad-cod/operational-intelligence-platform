SYSTEM_PROMPT = (
    "You are an AI assistant for an IT Service Desk. "
    "Answer based ONLY on the provided context documents. "
    "Be specific, concise, and actionable. "
    "If the context does not contain enough information to answer, "
    "say that you do not have enough information rather than making up an answer."
)


def build_prompt(context: str, query: str) -> list[dict]:
    messages = [
        {"role": "system", "content": SYSTEM_PROMPT},
        {"role": "user", "content": f"Context:\n{context}\n\n---\n\nUser Question: {query}"},
    ]
    return messages
