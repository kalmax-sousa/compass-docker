# Documentação da Implementação Wordpress com Docker no ambiente AWS

Autor: Kalmax dos Santos Sousa

## Requisitos

1. Instalação e configuração do DOCKER ou CONTAINERD no host EC2; Ponto adicional para o trabalho utilizar a instalação via script de Start Instance (user_data.sh)
2. Efetuar Deploy de uma aplicação Wordpress com: container de aplicação RDS database Mysql
3. Configuração da utilização do serviço EFS AWS para estáticos do container de aplicação Wordpress
4. Configuração do serviço de Load Balancer AWS para a aplicação Wordpress

## Arquitetura básica

<img src="/img/arq.png">

## Implementação

### VPC

A VPC segue a seguinte estrutura:

<img src="/img/vpc.jpg">

A VPC possui 3 sub-redes: 

- 1 sub-rede pública na `us-east-1a` com atribuição de endereços IP públicos habilitada;
- 1 sub-rede privada na `us-east-1b`;
- 1 sub-rede privada na `us-east-1c`.

Existem tabelas de roteamento diferentes para as rotas públicas e privadas:

- A tabela de roteamento pública está associada a um **Internet Gateway**, permitindo o acesso à internet.
- A tabela de roteamento privada é configurada com uma saída para o **NAT Gateway**, que por sua vez está associado à sub-rede pública para possibilitar o acesso controlado à internet a partir das sub-redes privadas.

### RDS

O Amazon RDS é um serviço de banco de dados relacional que pode ser facilmente criado por meio da Console AWS. Para configurar um banco de dados RDS, acesse a Console AWS e navegue até "RDS > Banco de Dados > Criar banco de dados".

O banco de dados RDS deve possuir as seguintes características:

- Método de criação: Padrão
- Tipo de mecanismo: MySQL
- Modelo: Nível gratuito
- Acesso privado

Durante a criação também é preciso informar um nome, usuário e senha para acessar o banco de dados  e associá-lo à VPC criada anteriormente e a um grupo de sub-redes (pode ser criado durante a criação do banco de dados selecionamento as sub-redes da VPC).

**Grupo de segurança RDS**

| Tipo | Protocolo | Porta | Origem |
| --- | --- | --- | --- |
| MYSQL/Aurora | TCP | 3306 | 10.0.0.0/16 |

### EFS

O Elastic File System é um sistema de arquivos compartilhados dentro da AWS e para configurá-lo, basta seguir os seguintes passos:

1. Acessar EFS no console AWS e clicar em “Criar sistema de arquivos”;
2. Definir um nome;
3. Associar à VPC criada anteriormente.
4. Ao finalizar, deve-se acessar a seção Rede do sistemas de arquivos e associa-lo a um grupo de segurança.

**Grupo de segurança EFS**

| Tipo | Protocolo | Porta | Origem |
| --- | --- | --- | --- |
| NFS | TCP | 2049 | 0.0.0.0/0 |
| UDP Personalizado | UDP | 2049 | 0.0.0.0/0 |

### Modelo de Execução

Para utilizar o Auto Scaling é necessário criar um modelo de execução de Instâncias EC2 que serão utilizadas no processo de escalonamento.

É necessário acessar “EC2 no console AWS > Modelos de Execução > Criar modelo de execução”

O modelo de execução possui a seguintes características:

- Imagem: Amazon Linux 2
- Tipo: t3.small
- Armazenamento: 16 GiB gp2
- Par de chaves criados anteriormente

Também [e necessário Inserir as TAGs, vincular à VPC criada anteriormente (não incluir sub-rede no modelo) e definir um grupo de segurança

**Grupo de Segurança EC2**

| Tipo | Protocolo | Porta | Origem |
| --- | --- | --- | --- |
| HTTP | TCP | 80 | 0.0.0.0/0 |
| HTTPS | TCP | 443 | 0.0.0.0/0 |
| NFS | TCP | 2049 | 0.0.0.0/0 |
| UDP Personalizada | UDP | 2049 | 0.0.0.0/0 |
| MYSQL/Aurora | TCP | 3306 | 0.0.0.0/0 |

A configuração das instâncias criadas e da aplicação Wordpress é feita através arquivo `user_data.sh` abaixo:

```bash
#!/bin/bash

##Instalação do Docker
sudo yum update -y
sudo amazon-linux-extras install docker -y
sudo service docker start
sudo systemctl enable docker.service
sudo usermod -a -G docker ec2-user

curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

##Instalação do EFS
sudo yum install -y amazon-efs-utils
sudo mkdir /efs
sudo chmod 777 /efs/
sudo mount -t efs -o tls fs-09fe1ec767bc01f72:/ /efs

echo "fs-09fe1ec767bc01f72:/ /efs efs _netdev,noresvport,tls,iam 0 0" >> /etc/fstab

export WORDPRESS_DB_USER=admin
export WORDPRESS_DB_PASSWORD=wordpress

mkdir /myapp

##Criação do Docker-Compose para Wordpress
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
```

### Auto Scaling

Com o modelo de execução, para a configuração do Auto Scaling é necessário informar:

- Nome
- Modelo de execução e sua versão
- VPC e as sub-redes de disponibilidade (apenas as sub-redes privadas)
- Definir os detalhes do grupo
    - Mínimo: 2
    - Desejado: 2
    - Máximo: 4

### Target Group

Para configurar o Target Group é necessário:

- Inserir um nome
- Selecionar:
    - Tipo de destino “Instâncias”
    - Protocolo: HTTP
    - Porta: 80
    - Tipo de endereço IP: IPv4
    - VPC criada anteriormente
    - Versão do protocolo: HTTP1
- É necessário registrar as Instâncias de destino.

### Load Balance

Para criar o Load Balance, basta acessar “O menu EC2 no console AWS > Load balancers > Criar load balancer” e seguir as seguintes configurações:

- Tipo: Application Load Balancer
- Esquema: Voltado para a Internet
- Tipo de endereço IP: IPv4
- Listener: Protocolo HTTP : Porta 80 - Avançar para: Selecionar o Target Group criado

Também é necessário indicar um nome, associar á VPC e definir um grupo de segurança

**Grupo de Segurança Load Balance**

| Tipo | Protocolo | Porta | Origem |
| --- | --- | --- | --- |
| HTTP | TCP | 80 | 0.0.0.0/0 |