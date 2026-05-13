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
# Ingestion CVE Dataset
# -----------------------------

def ingest():

    path_cve = "/opt/airflow/data/cve.csv"

    if not os.path.exists(path_cve):
        print(f"❌ Fichier introuvable : {path_cve}")
        return

    print("📂 Lecture cve.csv")

    df = pd.read_csv(path_cve)

    print(f"📊 Nombre de lignes : {len(df)}")
    print(f"📊 Nombre de colonnes : {len(df.columns)}")

    # Sécurité : suppression des colonnes dupliquées
    df = df.loc[:, ~df.columns.duplicated()]

    # Export MySQL
    df.to_sql(
        "raw_cve_data",
        con=engine,
        if_exists="replace",
        index=False,
        chunksize=5000
    )

    print("✅ Table raw_cve_data créée avec succès")


# -----------------------------
# Main
# -----------------------------

if __name__ == "__main__":
    ingest()