import pandas as pd
from sqlalchemy import create_engine
from pathlib import Path

# =========================================================
# MYSQL DATA WAREHOUSE CONNECTION
# =========================================================

DB_USER = "warehouse"
DB_PASSWORD = "warehouse_pass"
DB_HOST = "localhost"
DB_PORT = "3308"
DB_NAME = "it_data_warehouse_gold"

engine = create_engine(
    f"mysql+pymysql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
)

# =========================================================
# GOLD TABLES TO EXPORT
# =========================================================

gold_tables = [
    "gold_ticket_similarity",
    "gold_sla_prediction_features",
    "gold_asset_failure_risk",
    "gold_user_activity_anomalies"
]

# =========================================================
# OUTPUT DIRECTORY
# =========================================================

output_dir = Path("./parquet_exports")
output_dir.mkdir(exist_ok=True)

# =========================================================
# EXPORT EACH TABLE TO PARQUET
# =========================================================

for table_name in gold_tables:

    print(f"\n📦 Exporting {table_name} ...")

    # Read table
    query = f"SELECT * FROM {table_name}"
    df = pd.read_sql(query, engine)

    print(f"✅ Rows loaded: {len(df)}")

    # Output parquet path
    parquet_path = output_dir / f"{table_name}.parquet"

    # Export parquet
    df.to_parquet(
        parquet_path,
        engine="pyarrow",
        compression="snappy",
        index=False
    )

    print(f"✅ Saved: {parquet_path}")

print("\nAll gold tables exported successfully!")