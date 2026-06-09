import logging
import math
import pickle
import re
from collections import Counter
from pathlib import Path

logger = logging.getLogger(__name__)


class BM25Tokenizer:

    def __init__(self, corpus_path: str):
        path = Path(corpus_path)
        if not path.exists():
            raise FileNotFoundError(f"BM25 corpus not found at: {corpus_path}")

        logger.info("Loading BM25 corpus from %s...", corpus_path)
        with open(path, "rb") as f:
            corpus = pickle.load(f)

        logger.info("Corpus loaded: %d documents, computing vocabulary...", len(corpus))

        doc_freq: Counter = Counter()
        for tokens in corpus:
            if tokens:
                doc_freq.update(set(tokens))

        sorted_tokens = sorted(doc_freq.keys())
        self.vocab: dict[str, int] = {}
        self.idf: dict[str, float] = {}
        N = len(corpus)
        for idx, token in enumerate(sorted_tokens):
            df_t = doc_freq[token]
            self.vocab[token] = idx
            self.idf[token] = math.log(1.0 + (N - df_t + 0.5) / (df_t + 0.5))

        logger.info(
            "BM25 tokenizer loaded — vocab size: %d", len(self.vocab)
        )

    def _preprocess(self, text: str) -> list[str]:
        text = text.lower()
        tokens = re.findall(r"\b\w+\b", text)
        return [t for t in tokens if len(t) >= 2]

    def tokenize(self, text: str) -> tuple[list[int], list[float]]:
        if not text or not text.strip():
            return [], []

        tokens = self._preprocess(text)
        if not tokens:
            return [], []

        total = len(tokens)
        counts: dict[str, int] = {}
        for t in tokens:
            counts[t] = counts.get(t, 0) + 1

        indices: list[int] = []
        values: list[float] = []
        for token, count in counts.items():
            idx = self.vocab.get(token)
            if idx is None:
                continue
            tf = count / total
            score = tf * self.idf.get(token, 0.0)
            if score > 0.0:
                indices.append(idx)
                values.append(score)

        return indices, values

    def tokenize_batch(self, texts: list[str]) -> list[tuple[list[int], list[float]]]:
        return [self.tokenize(t) for t in texts]
