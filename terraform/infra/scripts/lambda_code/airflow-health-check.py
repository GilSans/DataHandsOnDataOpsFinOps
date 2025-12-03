import json
import urllib.request
import os

def lambda_handler(event, context):
    # URL do Airflow como variável de ambiente
    airflow_host = os.environ.get('AIRFLOW_HOST', 'ec2-13-58-137-11.us-east-2.compute.amazonaws.com')
    airflow_port = os.environ.get('AIRFLOW_PORT', '8080')
    url = f"http://{airflow_host}:{airflow_port}/health"

    try:
        with urllib.request.urlopen(url) as response:
            data = json.loads(response.read().decode())
        return data
    except Exception as e:
        return {
            "error": str(e),
            "metadatabase": {"status": "unhealthy"},
            "scheduler": {"status": "unhealthy"},
            "triggerer": {"status": "unhealthy"},
            "dag_processor": {"status": "unhealthy"}
        }
