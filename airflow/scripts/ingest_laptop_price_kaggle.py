import pandas as pd
from sqlalchemy import create_engine
import os

# -----------------------------
# Configuration MySQL
# -----------------------------

MYSQL_USER = "glpi"
MYSQL_PASSWORD = "secret"
MYSQL_HOST = "test_db"
MYSQL_PORT = "3306"

DATABASE_NAME = "kaggle_ds"

# -----------------------------
# Connexion MySQL
# -----------------------------

engine = create_engine(
    f"mysql+pymysql://{MYSQL_USER}:{MYSQL_PASSWORD}@{MYSQL_HOST}:{MYSQL_PORT}/{DATABASE_NAME}"
)

# -----------------------------
# Ingestion Laptop Price Dataset
# -----------------------------

def ingest():

    path_csv = "/opt/airflow/data/laptop_price.csv"

    if not os.path.exists(path_csv):
        print(f"❌ Fichier introuvable : {path_csv}")
        return

    print("📂 Lecture laptop_price.csv")

    chunk_size = 10000
    first_chunk = True

    for chunk in pd.read_csv(
        path_csv,
        chunksize=chunk_size,
        encoding="latin1",
        low_memory=True
    ):

        print(f"📦 Chunk reçu : {len(chunk)} lignes")

        # Supprime colonnes dupliquées
        chunk = chunk.loc[:, ~chunk.columns.duplicated()]

        chunk.to_sql(
            "raw_laptop_price_data",
            con=engine,
            if_exists="replace" if first_chunk else "append",
            index=False,
            method="multi"
        )

        first_chunk = False

        print("✅ Chunk inséré dans MySQL")

    print("🎉 Import laptop_price terminé")


# -----------------------------
# Main
# -----------------------------

if __name__ == "__main__":
    ingest()