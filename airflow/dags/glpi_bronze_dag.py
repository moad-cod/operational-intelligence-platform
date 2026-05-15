from airflow import DAG
from airflow.operators.bash import BashOperator
from datetime import datetime

with DAG(
    dag_id="glpi_bronze_ingestion",
    start_date=datetime(2024, 1, 1),
    schedule=None,
    catchup=False,
    tags=["bronze", "glpi", "mysql", "ai"],
) as dag:

    extract_glpi = BashOperator(
        task_id="extract_glpi_bronze",
        bash_command="""
        python /opt/airflow/scripts/extract_glpi_bronze.py
        """
    )