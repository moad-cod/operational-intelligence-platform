from airflow import DAG
from airflow.operators.bash import BashOperator
from datetime import datetime

with DAG(
    dag_id="ocs_bronze_ingestion",
    start_date=datetime(2024, 1, 1),
    schedule=None,
    catchup=False,
    tags=["bronze", "ocs", "mysql", "ai"],
) as dag:

    extract_ocs = BashOperator(
        task_id="extract_ocs_bronze",
        bash_command="""
        python /opt/airflow/scripts/extract_ocs_bronze.py
        """
    )