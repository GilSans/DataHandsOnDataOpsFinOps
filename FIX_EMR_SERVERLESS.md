# Fix: EMR Serverless Job Failed to Start

## 🔴 Problema
```
PersistentAppUI isn't available for jobs that never ran.
```

Isso significa que o job nunca foi executado, geralmente por falta de permissões IAM.

## ✅ Soluções

### 1. Aplicar Terraform Atualizado

```bash
cd terraform/infra
terraform apply
```

**Mudanças aplicadas:**
- ✅ Permissões S3 ampliadas para todos os buckets
- ✅ Política gerenciada AWS adicionada: `AmazonEMRServerlessBasicExecutionRole`
- ✅ Permissões Glue para criar/atualizar tabelas

### 2. Adicionar Permissões ao Airflow

O usuário/role do Airflow precisa de permissões para:
- Iniciar jobs no EMR Serverless
- Passar a role de execução (PassRole)

**Opção A: Via AWS CLI**
```bash
# Anexar política ao usuário do Airflow
aws iam put-user-policy \
  --user-name airflow-user \
  --policy-name EMRServerlessAccess \
  --policy-document file://airflow_emr_policy.json

# OU anexar à role do EC2 (se usar IAM Role)
aws iam put-role-policy \
  --role-name ec2-airflow-role \
  --policy-name EMRServerlessAccess \
  --policy-document file://airflow_emr_policy.json
```

**Opção B: Via Console AWS**
1. IAM → Users/Roles → Selecione o usuário/role do Airflow
2. Add permissions → Create inline policy
3. Cole o conteúdo de `airflow_emr_policy.json`

### 3. Verificar Configuração no Airflow

**Airflow Variables:**
```bash
airflow variables set emr_serverless_application_id "00g1nnlujbfmg80f"
airflow variables set emr_serverless_execution_role_arn "arn:aws:iam::ACCOUNT_ID:role/data-handson-mds-emr-serverless-execution-dev"
```

**Airflow Connection (aws_default):**
- AWS Access Key ID: `<sua_key>`
- AWS Secret Access Key: `<seu_secret>`
- Region: `us-east-2`

### 4. Verificar Logs do EMR Serverless

```bash
# Via AWS CLI
aws emr-serverless get-job-run \
  --application-id 00g1nnlujbfmg80f \
  --job-run-id <JOB_RUN_ID>

# Verificar logs no S3
aws s3 ls s3://cjmm-mds-lake-configs/logs/emr-serverless/
```

### 5. Testar Manualmente

```bash
# Testar se o script existe no S3
aws s3 ls s3://cjmm-mds-lake-configs/scripts/emr/emr_csv_to_parquet.py

# Testar se o arquivo de entrada existe
aws s3 ls s3://cjmm-mds-lake-configs/raw/input.csv
```

## 🔍 Checklist de Troubleshooting

- [ ] Terraform aplicado com novas permissões
- [ ] Política IAM anexada ao usuário/role do Airflow
- [ ] Variables do Airflow configuradas corretamente
- [ ] Connection `aws_default` configurada
- [ ] Script Python existe no S3
- [ ] Arquivo CSV de entrada existe no S3
- [ ] Role de execução do EMR tem permissões S3

## 📝 Permissões Necessárias

### EMR Serverless Execution Role
```json
{
  "S3": ["GetObject", "PutObject", "ListBucket"],
  "Glue": ["GetDatabase", "GetTable", "CreateTable"],
  "Logs": ["CreateLogGroup", "CreateLogStream", "PutLogEvents"]
}
```

### Airflow User/Role
```json
{
  "EMR-Serverless": ["StartJobRun", "GetJobRun", "CancelJobRun"],
  "IAM": ["PassRole"]
}
```

## 🚀 Próximos Passos

1. Aplique o Terraform
2. Configure as permissões do Airflow
3. Verifique as variables
4. Execute a DAG novamente
5. Monitore os logs no S3
