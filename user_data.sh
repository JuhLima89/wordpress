#!/bin/bash

# Atualiza o sistema
yum update -y

# Instala Docker e NFS
amazon-linux-extras install docker -y
yum install -y nfs-utils
systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user

# Instala Docker Compose v2
curl -L "https://github.com/docker/compose/releases/download/v2.24.6/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

# Monta EFS e garante montagem automática no boot
mkdir -p /mnt/efs
EFS_DNS=""
mount -t nfs4 -o nfsvers=4.1 ${EFS_DNS} /mnt/efs

# Adiciona entrada ao fstab se não existir
grep -q "${EFS_DNS}" /etc/fstab || echo "${EFS_DNS} /mnt/efs nfs4 defaults,_netdev 0 0" >> /etc/fstab

# Cria diretório da aplicação
mkdir -p /home/ec2-user/wordpress-app
cd /home/ec2-user/wordpress-app

# Define variáveis do RDS
RDS_HOST=""
RDS_PORT=""
RDS_USER=""
RDS_PASS=""
RDS_DB=""

# Cria docker-compose.yml
cat <<EOF > docker-compose.yml
version: '3.3'

services:
  wordpress:
    image: wordpress:latest
    ports:
      - "80:80"
    environment:
      WORDPRESS_DB_HOST: ${RDS_HOST}:${RDS_PORT}
      WORDPRESS_DB_USER: ${RDS_USER}
      WORDPRESS_DB_PASSWORD: ${RDS_PASS}
      WORDPRESS_DB_NAME: ${RDS_DB}
    volumes:
      - /mnt/efs/wp-content:/var/www/html/wp-content
    restart: always
EOF

# Define permissões
chown -R ec2-user:ec2-user /home/ec2-user/wordpress-app

# Inicia o container como ec2-user
su - ec2-user -c "cd /home/ec2-user/wordpress-app && docker-compose up -d"
