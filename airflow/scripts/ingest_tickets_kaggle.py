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
# Connexion DB kaggle_raw_data
# -----------------------------

engine = create_engine(
    f"mysql+pymysql://{MYSQL_USER}:{MYSQL_PASSWORD}@{MYSQL_HOST}:{MYSQL_PORT}/{DATABASE_NAME}"
)

# -----------------------------
# Ingestion
# -----------------------------

def ingest():

    path_csv1 = "/opt/airflow/data/dataset-tickets-multi-lang.csv"
    path_csv2 = "/opt/airflow/data/customer_support_tickets_200k.csv"

    # =====================================================
    # DATASET 1
    # =====================================================

    if os.path.exists(path_csv1):

        print("📂 Lecture dataset-tickets-multi-lang.csv")

        df1 = pd.read_csv(path_csv1)

        cols1 = [
            'subject',
            'body',
            'answer',
            'priority',
            'language'
        ]

        existing_cols1 = [c for c in cols1 if c in df1.columns]

        df1[existing_cols1].to_sql(
            'dataset_tickets_multi_lang',
            con=engine,
            if_exists='replace',
            index=False
        )

        print("✅ Table dataset_tickets_multi_lang créée")

    else:
        print(f"❌ Fichier introuvable : {path_csv1}")

    # =====================================================
    # DATASET 2
    # =====================================================

    if os.path.exists(path_csv2):

        print("📂 Lecture customer_support_tickets_200k.csv")

        df2 = pd.read_csv(path_csv2)

        cols2 = [
            'ticket_id',
            'category',
            'issue_description',
            'resolution_notes',
            'priority',
            'status'
        ]

        existing_cols2 = [c for c in cols2 if c in df2.columns]

        df2[existing_cols2].to_sql(
            'customer_support_tickets_200k',
            con=engine,
            if_exists='replace',
            index=False
        )

        print("✅ Table customer_support_tickets_200k créée")

    else:
        print(f"❌ Fichier introuvable : {path_csv2}")


# -----------------------------
# Main
# -----------------------------

if __name__ == "__main__":
    ingest()