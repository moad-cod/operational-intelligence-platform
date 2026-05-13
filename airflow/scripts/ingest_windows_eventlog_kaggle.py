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
    f"mysql+pymysql://{MYSQL_USER}:{MYSQL_PASSWORD}@{MYSQL_HOST}:{MYSQL_PORT}/{DATABASE_NAME}",
    pool_recycle=3600
)

# -----------------------------
# Ingestion Windows Event Log
# -----------------------------

def ingest():

    path_csv = "/opt/airflow/data/windows_eventlog.csv"

    if not os.path.exists(path_csv):
        print(f"❌ Fichier introuvable : {path_csv}")
        return

    print("📂 Début ingestion windows_eventlog.csv")

    chunk_size = 5000
    first_chunk = True

    csv_iterator = pd.read_csv(
        path_csv,
        chunksize=chunk_size,
        low_memory=True
    )

    for i, chunk in enumerate(csv_iterator):

        print(f"📦 Chunk {i + 1}")

        # Suppression colonnes dupliquées
        chunk = chunk.loc[:, ~chunk.columns.duplicated()]

        # Conversion colonnes texte
        for col in chunk.select_dtypes(include=['object']).columns:
            chunk[col] = chunk[col].astype(str)

        chunk.to_sql(
            "raw_windows_eventlog_data",
            con=engine,
            if_exists="replace" if first_chunk else "append",
            index=False
        )

        first_chunk = False

        print(f"✅ Chunk {i + 1} inséré")

    print("🎉 Import windows_eventlog terminé")


# -----------------------------
# Main
# -----------------------------

if __name__ == "__main__":
    ingest()