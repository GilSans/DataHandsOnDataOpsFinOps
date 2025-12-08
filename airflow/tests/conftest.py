import pytest
import os
from unittest.mock import patch


@pytest.fixture(scope="session", autouse=True)
def setup_airflow_environment():
    """Configura ambiente para testes do Airflow"""
    os.environ.setdefault('AIRFLOW_HOME', '/opt/airflow')
    os.environ.setdefault('AIRFLOW__CORE__DAGS_FOLDER', '/opt/airflow/dags')
    os.environ.setdefault('AIRFLOW__CORE__LOAD_EXAMPLES', 'False')
    os.environ.setdefault('AIRFLOW__CORE__UNIT_TEST_MODE', 'True')


@pytest.fixture
def mock_redshift_connection():
    """Mock para conexão Redshift"""
    with patch('airflow.hooks.base.BaseHook.get_connection') as mock_conn:
        mock_conn.return_value.host = 'test-redshift.amazonaws.com'
        mock_conn.return_value.port = 5439
        mock_conn.return_value.login = 'test_user'
        mock_conn.return_value.password = 'test_password'
        mock_conn.return_value.schema = 'public'
        yield mock_conn


@pytest.fixture
def mock_dbt_executable():
    """Mock para executável DBT"""
    with patch.dict(os.environ, {'AIRFLOW_HOME': '/opt/airflow'}):
        yield '/opt/airflow/dbt_venv/bin/dbt'
