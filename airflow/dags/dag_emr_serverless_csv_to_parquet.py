from airflow.decorators import dag
from airflow.providers.amazon.aws.operators.emr import EmrServerlessStartJobOperator
from airflow.providers.standard.operators.empty import EmptyOperator
from pendulum import datetime

S3_BUCKET = "cjmm-mds-lake-configs"
EMR_APPLICATION_ID = "{{ var.value.emr_serverless_application_id }}"
EMR_EXECUTION_ROLE_ARN = "{{ var.value.emr_serverless_execution_role_arn }}"

@dag(
    start_date=datetime(2025, 1, 1),
    schedule=None,
    catchup=False,
    tags=['emr-serverless', 'etl', 'csv-to-parquet']
)
def dag_emr_serverless_csv_to_parquet():

    start = EmptyOperator(task_id="start")

    emr_job = EmrServerlessStartJobOperator(
        task_id="run_csv_to_parquet",
        application_id=EMR_APPLICATION_ID,
        execution_role_arn=EMR_EXECUTION_ROLE_ARN,
        job_driver={
            "sparkSubmit": {
                "entryPoint": f"s3://{S3_BUCKET}/scripts/emr/emr_csv_to_parquet.py",
                "entryPointArguments": [
                    f"s3://{S3_BUCKET}/raw/input.csv",
                    f"s3://{S3_BUCKET}/staged/output_parquet/"
                ],
                "sparkSubmitParameters": "--conf spark.executor.cores=4 --conf spark.executor.memory=8g --conf spark.driver.cores=2 --conf spark.driver.memory=4g"
            }
        },
        configuration_overrides={
            "monitoringConfiguration": {
                "s3MonitoringConfiguration": {
                    "logUri": f"s3://{S3_BUCKET}/logs/emr-serverless/"
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

dag_emr_serverless_csv_to_parquet()
