#!/bin/bash
set -e

# Log de debug
exec > >(tee /var/log/user-data.log) 2>&1
echo "Iniciando bootstrap em $(date)"

# Atualiza pacotes
apt-get update -y
apt-get upgrade -y

# Instala dependências
apt-get install -y ca-certificates curl gnupg lsb-release

# Adiciona a chave GPG do Docker
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Adiciona o repositório Docker
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

# Instala Docker Engine
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io

# Habilita e inicia Docker
systemctl enable docker
systemctl start docker

# Adiciona o usuário 'ubuntu' ao grupo docker
usermod -aG docker ubuntu

# Instala Docker Compose CLI (v2)
curl -SL https://github.com/docker/compose/releases/download/v2.24.6/docker-compose-linux-x86_64 \
    -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Instala AWS CLI
apt-get install -y awscli

# Account ID passado via Terraform
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID}"
echo "AWS Account ID: $AWS_ACCOUNT_ID"

# Cria diretórios para Metabase e Airflow
mkdir -p /opt/metabase
mkdir -p /opt/airflow

# Baixa docker-compose do Metabase do S3
cd /opt/metabase
aws s3 cp s3://cjmm-mds-lake-configs/metabase/docker-compose.yml .

# Baixa arquivos do Airflow do S3
cd /opt/airflow
aws s3 sync s3://cjmm-mds-lake-configs/airflow/infra/ .

# Substitui AWS_ACCOUNT_ID no arquivo de configuração do Airflow
sed -i "s/\${AWS_ACCOUNT_ID}/$AWS_ACCOUNT_ID/g" config/airflow.cfg
echo "Airflow configurado para usar CloudWatch logs"

# Cria diretórios do Airflow (config já existe)
mkdir -p dags logs plugins

# Copia DAG de sync para pasta dags
cp dag_sync.py dags/

# Define permissões
chown -R ubuntu:ubuntu /opt/metabase /opt/airflow

# Configura variáveis de ambiente para AWS
echo 'export AWS_DEFAULT_REGION=us-east-2' >> /home/ubuntu/.bashrc

# Inicia Metabase
cd /opt/metabase
docker-compose up -d

# Aguarda um pouco antes de iniciar o Airflow
sleep 10

# Inicia Airflow
cd /opt/airflow
docker-compose up -d

# Configura para iniciar automaticamente no boot
echo "cd /opt/metabase && docker-compose up -d" >> /etc/rc.local
echo "cd /opt/airflow && docker-compose up -d" >> /etc/rc.local
chmod +x /etc/rc.local

echo "Bootstrap concluído em $(date)"
