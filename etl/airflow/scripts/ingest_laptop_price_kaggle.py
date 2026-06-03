import os, pandas as pd
from kaggle_base import get_warehouse_engine, logging

def ingest():
    path = os.getenv("LAPTOP_PRICE_CSV_PATH", "/opt/airflow/data/laptop_price.csv")
    engine = get_warehouse_engine()
    chunk_size = 10000
    first_chunk = True
    for chunk in pd.read_csv(path, chunksize=chunk_size, encoding="latin1", low_memory=True):
        chunk = chunk.loc[:, ~chunk.columns.duplicated()]
        chunk.to_sql(
            "raw_laptop_price_data", engine,
            if_exists="replace" if first_chunk else "append",
            index=False, method="multi"
        )
        first_chunk = False
        logging.info(f"[INGEST] Chunk done: {len(chunk)} rows")
    logging.info("[INGEST] raw_laptop_price_data complete")

if __name__ == "__main__":
    ingest()
