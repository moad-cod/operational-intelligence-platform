import pandas as pd
from sqlalchemy import create_engine
import os

# =========================================
# MYSQL CONFIGURATION
# =========================================

MYSQL_USER = "warehouse"
MYSQL_PASSWORD = "warehouse_pass"
MYSQL_HOST = "warehouse_db"
MYSQL_PORT = "3306"

DATABASE_NAME = "it_data_warehouse"

# =========================================
# MYSQL CONNECTION
# =========================================

engine = create_engine(
    f"mysql+pymysql://{MYSQL_USER}:{MYSQL_PASSWORD}@{MYSQL_HOST}:{MYSQL_PORT}/{DATABASE_NAME}"
)

# =========================================
# INGESTION FUNCTION
# =========================================

def ingest():

    path_csv1 = "/opt/airflow/data/dataset-tickets-multi-lang.csv"
    path_csv2 = "/opt/airflow/data/customer_support_tickets_200k.csv"

    # =====================================================
    # DATASET 1 : MULTI LANGUAGE TICKETS
    # =====================================================

    if os.path.exists(path_csv1):

        print("\n📂 Reading dataset-tickets-multi-lang.csv")

        df1 = pd.read_csv(
            path_csv1,
            low_memory=False
        )

        # =============================================
        # CLEAN COLUMN NAMES
        # =============================================

        df1.columns = (
            df1.columns
            .str.strip()
            .str.lower()
            .str.replace(" ", "_")
        )

        # =============================================
        # OPTIONAL METADATA
        # =============================================

        df1["source_dataset"] = "dataset_tickets_multi_lang"

        # =============================================
        # LOAD TO MYSQL
        # =============================================

        df1.to_sql(
            "dataset_tickets_multi_lang",
            con=engine,
            if_exists="replace",
            index=False,
            chunksize=5000
        )

        print("✅ dataset_tickets_multi_lang loaded")
        print(f"📊 Rows: {len(df1)}")
        print(f"📌 Columns: {list(df1.columns)}")

    else:

        print(f"❌ File not found: {path_csv1}")

    # =====================================================
    # DATASET 2 : CUSTOMER SUPPORT TICKETS
    # =====================================================

    if os.path.exists(path_csv2):

        print("\n📂 Reading customer_support_tickets_200k.csv")

        df2 = pd.read_csv(
            path_csv2,
            low_memory=False
        )

        # =============================================
        # CLEAN COLUMN NAMES
        # =============================================

        df2.columns = (
            df2.columns
            .str.strip()
            .str.lower()
            .str.replace(" ", "_")
        )

        # =============================================
        # OPTIONAL METADATA
        # =============================================

        df2["source_dataset"] = "customer_support_tickets_200k"

        # =============================================
        # LOAD TO MYSQL
        # =============================================

        df2.to_sql(
            "customer_support_tickets_200k",
            con=engine,
            if_exists="replace",
            index=False,
            chunksize=5000
        )

        print("✅ customer_support_tickets_200k loaded")
        print(f"📊 Rows: {len(df2)}")
        print(f"📌 Columns: {list(df2.columns)}")

    else:

        print(f"❌ File not found: {path_csv2}")


# =========================================
# MAIN
# =========================================

if __name__ == "__main__":

    ingest()