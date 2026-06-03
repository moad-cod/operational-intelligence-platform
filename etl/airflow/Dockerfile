FROM apache/airflow:2.7.1-python3.10

USER airflow

RUN pip install --no-cache-dir \
    pandas \
    sqlalchemy \
    pymysql \
    mysql-connector-python \
    apache-airflow-providers-mysql \
    python-dotenv
