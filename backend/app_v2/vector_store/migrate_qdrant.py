import json
import numpy as np
import pandas as pd

from qdrant_client import QdrantClient
from qdrant_client.models import (
    Distance,
    VectorParams,
    SparseVectorParams,
    SparseIndexParams,
    PointStruct,
    PayloadSchemaType,
    models,
)

# ==========================================================
# CONFIG
# ==========================================================

COLLECTION_NAME         = "incident_resolution"
VECTOR_DIM              = 384
BATCH_SIZE              = 500

EMBEDDINGS_PATH         = "../../parquet_exports_v2/embeddings.npy"
DATASET_PATH            = "../../parquet_exports_v2/retrieval_ready_dataset_v2.parquet"

# Hybrid retrieval constants (match your diagram)
DENSE_TOP_K             = 60   # FAISS branch
SPARSE_TOP_K            = 60   # BM25 branch
RERANK_TOP_K            = 10   # After LLM re-ranking

# ==========================================================
# LOAD DATA
# ==========================================================

print("Loading embeddings...")
embeddings = np.load(EMBEDDINGS_PATH)
print(f"  Shape: {embeddings.shape}")

print("Loading retrieval dataset...")
df = pd.read_parquet(DATASET_PATH)
df = df.reset_index(drop=True)

print(f"  Rows   : {len(df)}")
print(f"  Columns: {list(df.columns)}")

assert len(df) == len(embeddings), (
    f"Mismatch — embeddings: {len(embeddings)}, dataset: {len(df)}"
)

# ==========================================================
# BUILD SPARSE VECTORS FROM bm25_tokens
# Each row's bm25_tokens is a space-separated string of tokens.
# We build a simple TF-based sparse vector (token_hash → count).
# ==========================================================

print("Building BM25 sparse vectors from bm25_tokens...")

def tokens_to_sparse(token_str: str) -> tuple[list[int], list[float]]:
    """Convert a space-separated token string to sparse (indices, values)."""
    tokens = str(token_str).split()
    counts: dict[int, float] = {}
    for token in tokens:
        # Use positive 20-bit hash as dimension index
        idx = abs(hash(token)) % (2**20)
        counts[idx] = counts.get(idx, 0.0) + 1.0
    indices = list(counts.keys())
    values  = list(counts.values())
    return indices, values

sparse_vectors = [
    tokens_to_sparse(row["bm25_tokens"])
    for _, row in df.iterrows()
]

print(f"  Sparse vectors built: {len(sparse_vectors)}")

# ==========================================================
# CONNECT QDRANT
# ==========================================================

client = QdrantClient(host="localhost", port=6333)

# ==========================================================
# RECREATE COLLECTION
# Dense  vector  → cosine similarity  (FAISS branch)
# Sparse vector  → dot product        (BM25 branch)
# Both live in the same collection for hybrid search
# ==========================================================

existing = [c.name for c in client.get_collections().collections]

if COLLECTION_NAME in existing:
    print(f"Dropping existing collection '{COLLECTION_NAME}'...")
    client.delete_collection(COLLECTION_NAME)

print(f"Creating collection '{COLLECTION_NAME}'...")

client.create_collection(
    collection_name=COLLECTION_NAME,
    vectors_config={
        # Dense branch (FAISS / cosine)
        "dense": VectorParams(
            size=VECTOR_DIM,
            distance=Distance.COSINE,
        ),
    },
    sparse_vectors_config={
        # Sparse branch (BM25 / dot-product)
        "sparse_bm25": SparseVectorParams(
            index=SparseIndexParams(
                on_disk=False,  # keep in RAM for fast retrieval
            )
        ),
    },
)

# ==========================================================
# PAYLOAD INDEXES
# Supports: metadata filter, solution fetch, re-ranking
# ==========================================================

# --- Keyword (exact match / solution fetch by ID) ----------
KEYWORD_FIELDS = ["document_id", "rag_id", "chunk_id"]

for field in KEYWORD_FIELDS:
    if field in df.columns:
        client.create_payload_index(
            collection_name=COLLECTION_NAME,
            field_name=field,
            field_schema=PayloadSchemaType.KEYWORD,
        )
        print(f"  Keyword index: {field}")

# --- Integer (metadata filter) -----------------------------
INTEGER_FIELDS = ["priority_encoded", "chunk_index", "chunk_word_count"]

for field in INTEGER_FIELDS:
    if field in df.columns:
        client.create_payload_index(
            collection_name=COLLECTION_NAME,
            field_name=field,
            field_schema=PayloadSchemaType.INTEGER,
        )
        print(f"  Integer index: {field}")

# --- Float (re-ranking signal) -----------------------------
FLOAT_FIELDS = ["retrieval_quality_score"]

for field in FLOAT_FIELDS:
    if field in df.columns:
        client.create_payload_index(
            collection_name=COLLECTION_NAME,
            field_name=field,
            field_schema=PayloadSchemaType.FLOAT,
        )
        print(f"  Float index  : {field}")

# ==========================================================
# UPLOAD POINTS (dense + sparse + payload)
# ==========================================================

print("\nUploading vectors...")

for start in range(0, len(df), BATCH_SIZE):

    batch_df  = df.iloc[start : start + BATCH_SIZE]
    points    = []

    for local_i, (_, row) in enumerate(batch_df.iterrows()):

        vec_idx = start + local_i

        # ── Dense vector (FAISS branch) ───────────────────
        dense_vec = embeddings[vec_idx].tolist()

        # ── Sparse vector (BM25 branch) ───────────────────
        sp_indices, sp_values = sparse_vectors[vec_idx]

        # ── Parse metadata_json safely ────────────────────
        try:
            meta = json.loads(str(row["metadata_json"]))
        except (json.JSONDecodeError, TypeError):
            meta = {}

        # ── Payload — everything needed downstream ─────────
        # • chunk_text        → fed to LLM for solution generation
        # • document_id/rag_id → Fetch Solutions By ID step
        # • retrieval_quality_score / priority → re-ranking signals
        # • metadata fields   → metadata filter on embedding branch
        payload = {
            # Identity
            "chunk_id"              : str(row["chunk_id"]),
            "document_id"           : str(row["document_id"]),
            "rag_id"                : str(row["rag_id"]),

            # Chunk content (fed to LLM)
            "chunk_text"            : str(row["chunk_text"]),
            "chunk_index"           : int(row["chunk_index"]),
            "chunk_word_count"      : int(row["chunk_word_count"]),
            "chunk_token_estimate"  : int(row["chunk_token_estimate"]),

            # Retrieval signals (re-ranking)
            "priority_encoded"      : int(row["priority_encoded"]),
            "retrieval_quality_score": float(row["retrieval_quality_score"]),

            # Structured metadata (metadata filter branch)
            "metadata"              : meta,
        }

        points.append(
            PointStruct(
                id=vec_idx,
                vector={
                    "dense"      : dense_vec,
                    "sparse_bm25": models.SparseVector(
                        indices=sp_indices,
                        values=sp_values,
                    ),
                },
                payload=payload,
            )
        )

    client.upsert(
        collection_name=COLLECTION_NAME,
        points=points,
        wait=True,
    )

    uploaded = min(start + BATCH_SIZE, len(df))
    print(f"  {uploaded:>7} / {len(df)}")

# ==========================================================
# VERIFY
# ==========================================================

info = client.get_collection(COLLECTION_NAME)

print("\n✅ Migration complete")
print(f"   Collection : {COLLECTION_NAME}")
print(f"   Points     : {info.points_count}")
print(f"   Dense dim  : {VECTOR_DIM}  (cosine)")
print(f"   Sparse     : sparse_bm25  (dot-product / BM25)")
print(f"   Top-K plan : dense={DENSE_TOP_K}, sparse={SPARSE_TOP_K}, rerank={RERANK_TOP_K}")