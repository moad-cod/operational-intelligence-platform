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
    "mysql+pymysql://mouad:secret@platform_db:3306/db_ocs_{year}"
)

# =========================================
# TARGET WAREHOUSE
# =========================================

target_engine = create_engine(
    "mysql+pymysql://warehouse:warehouse_pass@warehouse_db:3306/it_data_warehouse"
)

# =========================================
# EXTRACTION
# =========================================

for year in years:

    print(f"\n========== OCS SOFTWARES {year} ==========")

    source_engine = create_engine(
        SOURCE_TEMPLATE.format(year=year)
    )

    try:

        print("📥 Extraction softwares")

        query = "SELECT * FROM softwares"

        df = pd.read_sql(query, source_engine)

        # =====================================
        # METADATA
        # =====================================

        df["source_year"] = year
        df["source_system"] = "OCS"

        # =====================================
        # LOAD TO WAREHOUSE
        # =====================================

        df.to_sql(
            "bronze_ocs_software",
            target_engine,
            if_exists="append",
            index=False,
            chunksize=5000
        )

        print(f"✅ bronze_ocs_software loaded ({year})")

    except Exception as e:

        print(f"❌ Error softwares ({year})")
        print(e)