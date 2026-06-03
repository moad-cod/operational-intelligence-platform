import os
import pandas as pd
from sqlalchemy import create_engine
from pathlib import Path
from dotenv import load_dotenv

load_dotenv()

DB_USER = os.getenv("WAREHOUSE_DB_USER", "warehouse")
DB_PASSWORD = os.getenv("WAREHOUSE_DB_PASSWORD", "warehouse_pass")
DB_HOST = os.getenv("WAREHOUSE_DB_HOST", "localhost")
DB_PORT = os.getenv("WAREHOUSE_DB_PORT", "3308")
DB_NAME = os.getenv("GOLD_DB_NAME", "it_data_warehouse_gold")

engine = create_engine(
    f"mysql+pymysql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
)

gold_tables = [
    "gold_ticket_similarity",
    "gold_sla_prediction_features",
    "gold_asset_failure_risk",
    "gold_user_activity_anomalies"
]

script_dir = Path(__file__).parent
output_dir = script_dir / "parquet_exports"
output_dir.mkdir(exist_ok=True)

for table_name in gold_tables:
    query = f"SELECT * FROM {table_name}"
    df = pd.read_sql(query, engine)
    parquet_path = output_dir / f"{table_name}.parquet"
    df.to_parquet(
        parquet_path,
        engine="pyarrow",
        compression="snappy",
        index=False
    )

print("All gold tables exported successfully!")