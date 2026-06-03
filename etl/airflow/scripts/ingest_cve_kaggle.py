import os
from kaggle_base import ingest_csv

def drop_dup_cols(df):
    return df.loc[:, ~df.columns.duplicated()]

def ingest():
    path = os.getenv("CVE_CSV_PATH", "/opt/airflow/data/cve.csv")
    ingest_csv(path, "raw_cve_data", transform_fn=drop_dup_cols)

if __name__ == "__main__":
    ingest()
