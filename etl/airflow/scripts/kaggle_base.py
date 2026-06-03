import os, time, logging
import pandas as pd
from sqlalchemy import create_engine
from dotenv import load_dotenv
load_dotenv()

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s"
)

def get_warehouse_engine():
    url = (
        f"mysql+pymysql://{os.getenv('WAREHOUSE_DB_USER', 'warehouse')}:"
        f"{os.getenv('WAREHOUSE_DB_PASSWORD', 'warehouse_pass')}@"
        f"{os.getenv('WAREHOUSE_DB_HOST', 'warehouse_db')}:"
        f"{os.getenv('WAREHOUSE_DB_PORT', '3306')}/it_data_warehouse"
    )
    return create_engine(url, pool_pre_ping=True)

def ingest_csv(
    csv_path: str,
    table_name: str,
    transform_fn=None,
    chunksize: int = 5000,
    dry_run: bool = False,
) -> int:
    t0 = time.time()
    logging.info(f"[INGEST] Reading {csv_path}")
    try:
        df = pd.read_csv(csv_path)
    except FileNotFoundError:
        logging.error(f"[INGEST] File not found: {csv_path}")
        raise

    if transform_fn:
        df = transform_fn(df)

    logging.info(f"[INGEST] {len(df):,} rows ready for {table_name}")

    if dry_run:
        logging.info(f"[INGEST] DRY RUN - skipping insert")
        return len(df)

    engine = get_warehouse_engine()
    df.to_sql(
        table_name, engine,
        if_exists="append", index=False,
        chunksize=chunksize, method="multi"
    )
    elapsed = time.time() - t0
    logging.info(f"[INGEST] {table_name}: {len(df):,} rows in {elapsed:.1f}s")
    return len(df)
