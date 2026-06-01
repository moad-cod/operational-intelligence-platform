from app.core.config import settings
from app.core.logging import logger
from app.retrieval.hybrid.hybrid_retriever import hybrid_search
from app.reranking.cross_encoder.reranker import rerank_results
from app.rag_pipeline.context.context_builder import build_context
from app.rag_pipeline.generation.generator import generate_response


def retrieve_rerank_generate(
    query: str,
    top_k_retrieval: int = 10,
    top_k_rerank: int = 5,
) -> tuple[str, list[dict], str]:
    logger.info("Pipeline: retrieve → rerank → generate for query='%s'", query[:80])

    hybrid_df = hybrid_search(query=query, top_k=top_k_retrieval)

    reranked_df = rerank_results(query=query, hybrid_df=hybrid_df, top_k=top_k_rerank)

    context = build_context(reranked_df)

    response = generate_response(context=context, query=query)

    context_docs = []
    for _, row in reranked_df.iterrows():
        context_docs.append({
            "chunk_id": row["chunk_id"],
            "text": row["text"],
            "score": float(row.get("rerank_score", row.get("rrf_score", 0))),
            "retriever": "hybrid+rerank",
        })

    logger.info("Pipeline complete: %d context docs, response length %d",
                len(context_docs), len(response))
    return response, context_docs, context
