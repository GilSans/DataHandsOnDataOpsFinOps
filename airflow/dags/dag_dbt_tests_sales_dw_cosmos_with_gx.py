from airflow.decorators import dag
from airflow.operators.dummy_operator import DummyOperator
from airflow.operators.python import PythonVirtualenvOperator
from airflow.operators.python import PythonOperator
from airflow.utils.context import Context

from cosmos import (
    DbtTaskGroup,
    ProjectConfig,
    ProfileConfig,
    RenderConfig,
    ExecutionConfig,
)
from cosmos.profiles import RedshiftUserPasswordProfileMapping
from cosmos.constants import TestBehavior

from pendulum import datetime

import os

from utils import utils

CONNECTION_ID = "redshift_default"
DB_NAME = "amazonsales"
SCHEMA_NAME = "public"

# ROOT_PATH = "/opt/airflow/dags"
ROOT_PATH = "/usr/local/airflow/dags" #MWAA
DBT_PROJECT_PATH = f"{ROOT_PATH}/dbt/sales_dw_dbt_tests_with_gx"

profile_config = ProfileConfig(
    profile_name="sales_dw_dbt_tests_with_gx",
    target_name="dev",
    profile_mapping=RedshiftUserPasswordProfileMapping(
        conn_id=CONNECTION_ID,
        profile_args={"schema": SCHEMA_NAME},
    ),
)

execution_config = ExecutionConfig(
    dbt_executable_path=f"{os.environ['AIRFLOW_HOME']}/dbt_venv/bin/dbt",
    # execution_mode=ExecutionMode.VIRTUALENV,
)


@dag(start_date=datetime(2025, 4, 1), schedule=None, catchup=False)
def dag_dbt_tests_sales_dw_cosmos_with_gx():

    start_process = DummyOperator(task_id="start_process")

    transform_data = DbtTaskGroup(
        group_id="transform_data",
        project_config=ProjectConfig(DBT_PROJECT_PATH),
        profile_config=profile_config,
        execution_config=execution_config,
        operator_args={
            "install_deps": True,
            "full_refresh": True,
        },
        render_config=RenderConfig(
            test_behavior=TestBehavior.AFTER_EACH,
            should_detach_multiple_parents_tests=True, #não falhar tasks seguintes
        ),
        default_args={"retries": 0},
    )

    start_process >> transform_data


dag_dbt_tests_sales_dw_cosmos_with_gx()
