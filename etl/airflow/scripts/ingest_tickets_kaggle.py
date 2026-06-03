import os, pandas as pd
from kaggle_base import get_warehouse_engine, logging

def clean_columns(df):
    df.columns = df.columns.str.strip().str.lower().str.replace(" ", "_")
    return df

def ingest():
    engine = get_warehouse_engine()
    paths = [
        ("/opt/airflow/data/dataset-tickets-multi-lang.csv", "dataset_tickets_multi_lang", "dataset_tickets_multi_lang"),
        ("/opt/airflow/data/customer_support_tickets_200k.csv", "customer_support_tickets_200k", "customer_support_tickets_200k"),
    ]
    for path, table, source_name in paths:
        if not os.path.exists(path):
            logging.warning(f"[INGEST] File not found: {path}")
            continue
        df = pd.read_csv(path, low_memory=False)
        df = clean_columns(df)
        df["source_dataset"] = source_name
        df.to_sql(table, engine, if_exists="replace", index=False, chunksize=5000)
        logging.info(f"[INGEST] {table}: {len(df):,} rows")

if __name__ == "__main__":
    ingest()
