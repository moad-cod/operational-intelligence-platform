from airflow import DAG
from airflow.operators.bash import BashOperator
from datetime import datetime

default_args = {
    "owner": "mouad",
    "start_date": datetime(2025, 1, 1),
    "retries": 1
}

with DAG(
    dag_id="ocs_softwares_ingestion",
    default_args=default_args,
    schedule="@daily",
    catchup=False,
    tags=["ocs", "bronze", "software"]
) as dag:

    ingest_softwares = BashOperator(
        task_id="ingest_ocs_softwares",
        bash_command="""
        python /opt/airflow/scripts/ingest_ocs_softwares.py
        """
    )

    ingest_softwares