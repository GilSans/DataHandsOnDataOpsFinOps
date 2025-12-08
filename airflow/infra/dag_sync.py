from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.bash import BashOperator

default_args = {
    'owner': 'dataops-team',
    'depends_on_past': False,
    'start_date': datetime(2025, 12, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=1),
}

dag = DAG(
    'dag_sync_s3_to_airflow',
    default_args=default_args,
    description='Sync DAGs from S3 to Airflow dags folder',
    schedule=timedelta(minutes=5),
    catchup=False,
    tags=['sync', 'dags', 's3'],
)

sync_bash_task = BashOperator(
    task_id='sync_dags_bash',
    bash_command='''
    aws s3 sync s3://cjmm-mds-lake-configs/airflow/dags/ /opt/airflow/dags/
    chown -R 50000:0 /opt/airflow/dags
    chmod -R 755 /opt/airflow/dags
    echo "DAGs sincronizadas com sucesso"
    ''',
    dag=dag,
)

sync_bash_task
