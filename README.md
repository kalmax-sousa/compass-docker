# Documentação da Implementação Wordpress com Docker no ambiente AWS

Autor: Kalmax dos Santos Sousa

## Requisitos

1. Instalação e configuração do DOCKER ou CONTAINERD no host EC2; Ponto adicional para o trabalho utilizar a instalação via script de Start Instance (user_data.sh)
2. Efetuar Deploy de uma aplicação Wordpress com: container de aplicação RDS database Mysql
3. Configuração da utilização do serviço EFS AWS para estáticos do container de aplicação Wordpress
4. Configuração do serviço de Load Balancer AWS para a aplicação Wordpress

## Arquitetura básica

![Untitled](Documentac%CC%A7a%CC%83o%20da%20Implementac%CC%A7a%CC%83o%20Wordpress%20com%20Do%20301aaa7f2a8e42d9b4b3a5443fa8cf19/Untitled.png)

## Implementação

### 1. VPC

A VPC segue a seguinte estrutura:

![Untitled](Documentac%CC%A7a%CC%83o%20da%20Implementac%CC%A7a%CC%83o%20Wordpress%20com%20Do%20301aaa7f2a8e42d9b4b3a5443fa8cf19/Untitled.jpeg)

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

### Auto Scaling

### Load Balance