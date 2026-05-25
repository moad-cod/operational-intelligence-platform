from airflow import DAG
from airflow.operators.bash import BashOperator
from datetime import datetime

with DAG(
    dag_id='ingest_cve_kaggle',
    start_date=datetime(2024, 1, 1),
    schedule=None,
    catchup=False,
    tags=['kaggle', 'security', 'cve'],
) as dag:

    run_ingestion = BashOperator(
        task_id='run_python_cve_ingest',
        bash_command='python /opt/airflow/scripts/ingest_cve_kaggle.py'
    )