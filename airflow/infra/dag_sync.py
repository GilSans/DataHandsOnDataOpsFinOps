from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.providers.amazon.aws.operators.s3 import S3ListOperator
from airflow.providers.amazon.aws.hooks.s3 import S3Hook
from airflow.operators.python import PythonOperator
import os
import logging

default_args = {
    'owner': 'dataops-team',
    'depends_on_past': False,
    'start_date': datetime(2024, 1, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=1),
}

dag = DAG(
    'dag_sync_s3_to_airflow',
    default_args=default_args,
    description='Sync DAGs from S3 to Airflow dags folder',
    schedule_interval=timedelta(minutes=5),
    catchup=False,
    tags=['sync', 'dags', 's3'],
)

def sync_dags_from_s3():
    """
    Sincroniza DAGs do S3 para a pasta local do Airflow
    """
    s3_bucket = 'cjmm-mds-lake-configs'
    s3_prefix = 'airflow/dags/'
    local_dags_path = '/opt/airflow/dags'

    try:
        # Usa AWS CLI para sincronizar
        sync_command = f"aws s3 sync s3://{s3_bucket}/{s3_prefix} {local_dags_path}/ --delete"
        os.system(sync_command)

        # Define permissões corretas
        os.system(f"chown -R 50000:0 {local_dags_path}")
        os.system(f"chmod -R 755 {local_dags_path}")

        logging.info(f"DAGs sincronizadas com sucesso de s3://{s3_bucket}/{s3_prefix}")

    except Exception as e:
        logging.error(f"Erro ao sincronizar DAGs: {str(e)}")
        raise

sync_task = PythonOperator(
    task_id='sync_dags_from_s3',
    python_callable=sync_dags_from_s3,
    dag=dag,
)

# Task alternativa usando BashOperator
sync_bash_task = BashOperator(
    task_id='sync_dags_bash',
    bash_command='''
    aws s3 sync s3://cjmm-mds-lake-configs/airflow/dags/ /opt/airflow/dags/ --delete
    chown -R 50000:0 /opt/airflow/dags
    chmod -R 755 /opt/airflow/dags
    echo "DAGs sincronizadas com sucesso"
    ''',
    dag=dag,
)

# Usar apenas uma das tasks
sync_bash_task
