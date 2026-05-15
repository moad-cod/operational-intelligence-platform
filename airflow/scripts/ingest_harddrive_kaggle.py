import pandas as pd
from sqlalchemy import create_engine
import os

# -----------------------------
# Configuration MySQL
# -----------------------------

MYSQL_USER = "warehouse"
MYSQL_PASSWORD = "warehouse_pass"
MYSQL_HOST = "warehouse_db"
MYSQL_PORT = "3306"

DATABASE_NAME = "it_data_warehouse"

# -----------------------------
# Connexion MySQL
# -----------------------------

engine = create_engine(
    f"mysql+pymysql://{MYSQL_USER}:{MYSQL_PASSWORD}@{MYSQL_HOST}:{MYSQL_PORT}/{DATABASE_NAME}",
    pool_recycle=3600
)

# -----------------------------
# Ingestion Hard Drive Dataset
# -----------------------------

def ingest():

    path_harddrive = "/opt/airflow/data/harddrive.csv"

    if not os.path.exists(path_harddrive):
        print(f"❌ Fichier introuvable : {path_harddrive}")
        return

    print("📂 Début ingestion harddrive_dataset.csv")

    chunk_size = 5000
    first_chunk = True

    csv_iterator = pd.read_csv(
        path_harddrive,
        chunksize=chunk_size,
        low_memory=True
    )

    for i, chunk in enumerate(csv_iterator):

        print(f"📦 Chunk {i + 1}")

        # Nettoyage mémoire
        chunk = chunk.loc[:, ~chunk.columns.duplicated()]

        # Conversion types lourds
        for col in chunk.select_dtypes(include=['object']).columns:
            chunk[col] = chunk[col].astype(str)

        chunk.to_sql(
            "raw_harddrive_data",
            con=engine,
            if_exists="replace" if first_chunk else "append",
            index=False
        )

        first_chunk = False

        print(f"✅ Chunk {i + 1} inséré")

    print("🎉 Import terminé")


# -----------------------------
# Main
# -----------------------------

if __name__ == "__main__":
    ingest()