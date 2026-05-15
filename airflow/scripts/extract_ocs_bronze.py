import pandas as pd
from sqlalchemy import create_engine

# =========================================
# YEARS
# =========================================

years = [2013, 2014, 2015]

# =========================================
# SOURCE CONNECTION TEMPLATE
# =========================================

SOURCE_TEMPLATE = (
    "mysql+pymysql://mouad:secret@glpi_ocs_db:3306/db_ocs_{year}"
)

# =========================================
# TARGET WAREHOUSE
# =========================================

target_engine = create_engine(
    "mysql+pymysql://warehouse:warehouse_pass@warehouse_db:3306/it_data_warehouse"
)

# =========================================
# OCS TABLES
# =========================================

tables = [

    # =====================================
    # CORE INVENTORY
    # =====================================

    "hardware",

    # =====================================
    # SOFTWARE / SECURITY
    # =====================================

    "software",

    # =====================================
    # STORAGE
    # =====================================

    "drives",
    "storages",

    # =====================================
    # MEMORY / BIOS
    # =====================================

    "memories",
    "bios",

    # =====================================
    # NETWORK
    # =====================================

    "networks"

]

# =========================================
# EXTRACTION
# =========================================

for year in years:

    print(f"\n========== OCS YEAR {year} ==========")

    source_engine = create_engine(
        SOURCE_TEMPLATE.format(year=year)
    )

    for table in tables:

        try:

            print(f"📥 Extraction {table}")

            query = f"SELECT * FROM {table}"

            df = pd.read_sql(query, source_engine)

            # =================================
            # EMPTY TABLE CHECK
            # =================================

            if df.empty:

                print(f"⚠️ Table vide : {table} ({year})")

                continue

            # =================================
            # METADATA
            # =================================

            df["source_year"] = year

            df["source_system"] = "OCS"

            target_table = f"bronze_ocs_{table}"

            # =================================
            # LOAD TO WAREHOUSE
            # =================================

            df.to_sql(
                target_table,
                target_engine,
                if_exists="append",
                index=False,
                chunksize=5000
            )

            print(f"✅ {target_table} alimentée")

        except Exception as e:

            print(f"❌ Erreur {table} ({year})")

            print(e)