from airflow import DAG
from airflow.operators.bash import BashOperator
from datetime import datetime

with DAG(
    dag_id='ingest_tickets_kaggle',
    start_date=datetime(2024, 1, 1),
    schedule=None,
    catchup=False,
    tags=['kaggle', 'bronze', 'mysql'],
) as dag:

    run_ingestion = BashOperator(
        task_id='run_python_tickets_ingest',
        bash_command='python /opt/airflow/scripts/ingest_tickets_kaggle.py'
    )