#!/bin/bash
set -ex

# Atualizar o sistema
yum update -y

# Instalar docker
amazon-linux-extras install docker -y
systemctl enable docker
systemctl start docker

# Adicionar ec2-user ao grupo docker para permitir rodar docker sem sudo
usermod -aG docker ec2-user

# Instalar docker-compose (versão estável)
DOCKER_COMPOSE_VERSION="v2.20.2"
curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-linux-x86_64" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

# Instalar nfs-utils para montar EFS
yum install -y nfs-utils

# Variáveis para EFS e RDS - editar conforme seu ambiente
EFS_ID=""  # Substitua pelo seu EFS ID
AWS_REGION=""  # Região do EFS e RDS
RDS_ENDPOINT=""
RDS_DB_NAME=""
RDS_USERNAME=""
RDS_PASSWORD=""
EFS_MOUNT_POINT="/mnt/efs"

# Criar diretório para montagem do EFS ANTES da montagem
mkdir -p ${EFS_MOUNT_POINT}
mkdir -p ${EFS_MOUNT_POINT}/wordpress
chown -R 1000:1000 ${EFS_MOUNT_POINT}/wordpress

# Adicionar no fstab para montar automaticamente no boot
grep -q "${EFS_ID}.efs.${AWS_REGION}.amazonaws.com:/" /etc/fstab || \
echo "${EFS_ID}.efs.${AWS_REGION}.amazonaws.com:/ ${EFS_MOUNT_POINT} nfs4 defaults,_netdev 0 0" >> /etc/fstab

# Montar EFS agora mesmo
mount -a

# Criar docker-compose.yml para o WordPress no diretório do ec2-user
cat > /home/ec2-user/docker-compose.yml <<EOF
version: '3.8'
services:
  wordpress:
    image: wordpress:latest
    ports:
      - "80:80"
    environment:
      WORDPRESS_DB_HOST: ${RDS_ENDPOINT}
      WORDPRESS_DB_NAME: ${RDS_DB_NAME}
      WORDPRESS_DB_USER: ${RDS_USERNAME}
      WORDPRESS_DB_PASSWORD: ${RDS_PASSWORD}
    volumes:
      - ${EFS_MOUNT_POINT}/wordpress:/var/www/html
    restart: always
EOF

# Ajustar permissões do diretório do docker-compose
chown ec2-user:ec2-user /home/ec2-user/docker-compose.yml

# Rodar docker-compose como ec2-user (usando o PATH correto para docker-compose)
sudo -u ec2-user /usr/bin/docker-compose -f /home/ec2-user/docker-compose.yml up -d


