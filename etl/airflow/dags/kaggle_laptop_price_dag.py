from airflow import DAG
from airflow.operators.bash import BashOperator
from datetime import datetime

with DAG(
    dag_id='ingest_laptop_price_kaggle',
    start_date=datetime(2024, 1, 1),
    schedule=None,
    catchup=False,
    tags=['kaggle', 'mysql', 'bronze'],
) as dag:

    run_ingestion = BashOperator(
        task_id='run_python_laptop_price_ingest',
        bash_command='python /opt/airflow/scripts/ingest_laptop_price_kaggle.py'
    )