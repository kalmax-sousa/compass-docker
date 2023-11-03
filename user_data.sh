#!/bin/bash

sudo yum update -y
sudo amazon-linux-extras install docker -y
sudo service docker start
sudo systemctl enable docker.service
sudo usermod -a -G docker ec2-user

curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

export WORDPRESS_DB_USER=admin
export WORDPRESS_DB_PASSWORD=wordpress

mkdir /myapp

cat << EOF > /myapp/docker-compose.yml
version: '3.1'

services:

  wordpress:
    image: wordpress
    restart: always
    ports:
      - 80:80
    environment:
      WORDPRESS_DB_HOST: wordpress.c1k5hjsnsxov.us-east-1.rds.amazonaws.com:3306
      WORDPRESS_DB_USER: $WORDPRESS_DB_USER
      WORDPRESS_DB_PASSWORD: $WORDPRESS_DB_PASSWORD
      WORDPRESS_DB_NAME: wordpress
    volumes:
      - /efs/wordpress:/var/www/html

  db:
    image: mysql:5.7
    restart: always
    environment:
      MYSQL_DATABASE: wordpress
      MYSQL_USER: admin
      MYSQL_PASSWORD: wordpress
      MYSQL_RANDOM_ROOT_PASSWORD: '1'
    volumes:
      - db:/var/lib/mysql

volumes:
  wordpress:
  db:
EOF

cd /myapp

docker-compose up -d
cd ..

sudo yum install -y amazon-efs-utils
sudo mkdir /efs
sudo mount -t efs -o tls fs-09fe1ec767bc01f72:/ /efs

echo "fs-09fe1ec767bc01f72:/ /efs efs _netdev,noresvport,tls,iam 0 0" >> /etc/fstab