import os, pandas as pd
from sqlalchemy import create_engine
from dotenv import load_dotenv
load_dotenv()

# =========================================
# YEARS
# =========================================

years = [2013, 2014, 2015]

# =========================================
# SOURCE CONNECTION TEMPLATE
# =========================================

SOURCE_TEMPLATE = (
    f"mysql+pymysql://{os.getenv('PLATFORM_DB_USER', 'mouad')}:"
    f"{os.getenv('PLATFORM_DB_PASSWORD', 'secret')}@"
    f"{os.getenv('PLATFORM_DB_HOST', 'glpi_ocs_db')}:"
    f"{os.getenv('PLATFORM_DB_PORT', '3306')}/db_glpi_{{year}}"
)

# =========================================
# TARGET WAREHOUSE
# =========================================

target_engine = create_engine(
    f"mysql+pymysql://{os.getenv('WAREHOUSE_DB_USER', 'warehouse')}:"
    f"{os.getenv('WAREHOUSE_DB_PASSWORD', 'warehouse_pass')}@"
    f"{os.getenv('WAREHOUSE_DB_HOST', 'warehouse_db')}:"
    f"{os.getenv('WAREHOUSE_DB_PORT', '3306')}/it_data_warehouse"
)

# =========================================
# TABLES
# =========================================

tables = [

    # =====================================
    # TICKETS / NLP
    # =====================================

    "glpi_tickets",
    "glpi_ticketfollowups",
    "glpi_itilcategories",
    "glpi_logs",

    # =====================================
    # USERS
    # =====================================

    "glpi_users",

    # =====================================
    # ASSETS
    # =====================================

    "glpi_computers",
    "glpi_infocoms",

    # =====================================
    # HARDWARE COMPONENTS
    # =====================================

    "glpi_deviceprocessors",
    "glpi_devicememories",
    "glpi_devicegraphiccards"

]

# =========================================
# EXTRACTION
# =========================================

for year in years:

    print(f"\n========== YEAR {year} ==========")

    source_engine = create_engine(
        SOURCE_TEMPLATE.format(year=year)
    )

    for table in tables:

        try:

            print(f"📥 Extraction {table}")

            query = f"SELECT * FROM {table}"

            df = pd.read_sql(query, source_engine)

            # =================================
            # METADATA
            # =================================

            df["source_year"] = year

            df["source_system"] = "GLPI"

            target_table = f"bronze_{table}"

            # =================================
            # LOAD TO BRONZE
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