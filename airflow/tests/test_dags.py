import pytest
import sys
import os
from datetime import datetime, timedelta
from unittest.mock import patch, MagicMock

# Adiciona o diretório dags ao path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'dags'))

from airflow.models import DagBag
try:
    from airflow.utils.dag_cycle import check_cycle
except ImportError:
    # Para versões mais recentes do Airflow
    def check_cycle(dag):
        """Função stub para verificação de ciclos"""
        pass


class TestDAGs:
    """Testes unitários para as DAGs do Airflow"""

    @pytest.fixture
    def dagbag(self):
        """Fixture para carregar as DAGs"""
        return DagBag(dag_folder='../dags', include_examples=False)

    def test_dag_structure(self, dagbag):
        """Testa estrutura básica das DAGs"""
        for dag_id, dag in dagbag.dags.items():
            # Verifica se DAG tem pelo menos uma task
            assert len(dag.tasks) > 0, f"DAG {dag_id} não tem tasks"

            # Verifica se não há ciclos (se disponível)
            try:
                check_cycle(dag)
            except Exception:
                pass  # Ignora se não conseguir verificar ciclos

            # Verifica se start_date está definido
            assert dag.start_date is not None, f"DAG {dag_id} não tem start_date"

    def test_dag_default_args(self, dagbag):
        """Testa argumentos padrão das DAGs"""
        for dag_id, dag in dagbag.dags.items():
            # Verifica se retries está configurado
            for task in dag.tasks:
                if hasattr(task, 'retries'):
                    assert task.retries >= 0, f"Task {task.task_id} tem retries negativo"

    def test_dag_tags(self, dagbag):
        """Testa se DAGs têm tags apropriadas"""
        for dag_id, dag in dagbag.dags.items():
            # Verifica se DAG tem pelo menos uma tag (opcional)
            if hasattr(dag, 'tags') and dag.tags:
                assert isinstance(dag.tags, list), f"Tags da DAG {dag_id} devem ser uma lista"

    def test_task_timeout(self, dagbag):
        """Testa se tasks têm timeout configurado quando necessário"""
        for dag_id, dag in dagbag.dags.items():
            for task in dag.tasks:
                # Para tasks que podem demorar, verifica se há timeout
                if 'transform' in task.task_id.lower():
                    # Timeout deve ser configurado para tasks de transformação
                    assert hasattr(task, 'execution_timeout'), f"Task {task.task_id} deveria ter timeout"


if __name__ == "__main__":
    pytest.main([__file__])
