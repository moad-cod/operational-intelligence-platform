import os, pandas as pd
from kaggle_base import get_warehouse_engine, logging

def ingest():
    path = os.getenv("WINDOWS_EVENTLOG_CSV_PATH", "/opt/airflow/data/windows_eventlog.csv")
    engine = get_warehouse_engine()
    chunk_size = 5000
    first_chunk = True
    for chunk in pd.read_csv(path, chunksize=chunk_size, low_memory=True):
        chunk = chunk.loc[:, ~chunk.columns.duplicated()]
        for col in chunk.select_dtypes(include=["object"]).columns:
            chunk[col] = chunk[col].astype(str)
        chunk.to_sql(
            "raw_windows_eventlog_data", engine,
            if_exists="replace" if first_chunk else "append",
            index=False
        )
        first_chunk = False
        logging.info(f"[INGEST] Chunk done: {len(chunk)} rows")
    logging.info("[INGEST] raw_windows_eventlog_data complete")

if __name__ == "__main__":
    ingest()
