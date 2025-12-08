from airflow.decorators import dag
from airflow.providers.amazon.aws.operators.emr import EmrServerlessStartJobOperator
from airflow.providers.standard.operators.empty import EmptyOperator
from pendulum import datetime

S3_BUCKET_CONFIG = "cjmm-mds-lake-configs"
S3_BUCKET_INPUT = "cjmm-mds-lake-raw"
S3_TABLES_NAMESPACE = "emr_serverless_exemplo"
S3_TABLES_TABLE = "stg_sales"

EMR_APPLICATION_ID = "{{ var.value.emr_serverless_application_id }}"
EMR_EXECUTION_ROLE_ARN = "{{ var.value.emr_serverless_execution_role_arn }}"
S3_TABLES_BUCKET_ARN = "{{ var.value.s3_tables_bucket_arn }}"


@dag(
    start_date=datetime(2025, 1, 1),
    schedule=None,
    catchup=False,
    tags=['emr-serverless', 'etl', 's3-tables', 'iceberg']
)
def dag_emr_serverless_csv_to_s3tables():

    start = EmptyOperator(task_id="start")

    emr_job = EmrServerlessStartJobOperator(
        task_id="run_csv_to_s3tables",
        application_id=EMR_APPLICATION_ID,
        execution_role_arn=EMR_EXECUTION_ROLE_ARN,
        job_driver={
            "sparkSubmit": {
                "entryPoint": f"s3://{S3_BUCKET_CONFIG}/scripts/emr/emr_csv_to_s3tables.py",
                "entryPointArguments": [
                    f"s3://{S3_BUCKET_INPUT}/sales/amazon.csv",
                    S3_TABLES_BUCKET_ARN,
                    S3_TABLES_NAMESPACE,
                    S3_TABLES_TABLE
                ],
                "sparkSubmitParameters": "--conf spark.executor.cores=4 --conf spark.executor.memory=8g --conf spark.driver.cores=2 --conf spark.driver.memory=4g --jars s3://cjmm-mds-lake-configs/jars/s3-tables-catalog-for-iceberg-0.1.7.jar"
            }
        },
        configuration_overrides={
            "monitoringConfiguration": {
                "s3MonitoringConfiguration": {
                    "logUri": f"s3://{S3_BUCKET_CONFIG}/logs/emr-serverless/"
                },
                "cloudWatchLoggingConfiguration": {
                    "enabled": True,
                    "logGroupName": "/aws/emr-serverless/data-handson-mds-spark-dev"
                }
            }
        },
        aws_conn_id="aws_default",
        wait_for_completion=True,
    )

    end = EmptyOperator(task_id="end")

    start >> emr_job >> end

dag_emr_serverless_csv_to_s3tables()
