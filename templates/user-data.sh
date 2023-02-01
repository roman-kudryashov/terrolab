#!/bin/bash -xe

DB_PASSWORD=$(aws ssm get-parameter --name ${ssm_db_password} --query Parameter.Value --with-decryption --region ${region} --output text)

### Install pre-reqs
curl -sL https://rpm.nodesource.com/setup_14.x | sudo bash -
yum install -y nodejs amazon-efs-utils
npm install ghost-cli@latest -g

adduser ghost_user
usermod -aG wheel ghost_user
cd /home/ghost_user/

sudo -u ghost_user ghost install local

### EFS mount
mkdir -p /home/ghost_user/ghost/content
mount -t efs -o tls ${efs_id}:/ /home/ghost_user/ghost/content
mkdir -p /home/ghost_user/ghost/content/data
chmod 0777 -R /home/ghost_user/ghost/content

cat << EOF > config.development.json

{
  "url": "http://${alb_url}",
  "server": {
    "port": 2368,
    "host": "0.0.0.0"
  },
  "database": {
    "client": "mysql",
    "connection": {
    "host": "${db_url}",
    "port": 3306,
    "user": "${db_user}",
    "password": "$DB_PASSWORD",
    "database": "${db_name}"
    }
  },
  "mail": {
    "transport": "Direct"
  },
  "logging": {
    "transports": [
      "file",
      "stdout"
    ]
  },
  "process": "local",
  "paths": {
    "contentPath": "/home/ghost_user/ghost/content"
  }
}
EOF

sudo -u ghost_user ghost stop
sudo -u ghost_user ghost start