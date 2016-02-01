# Installing st2 on centos/rhel linux

Follow this guide and we'll lead you through the basic installation and setup steps.

## Setting up repos and fetching required software

First let's update the system and fetch software which will be required during installation and setup process:
```shell
sudo yum makecache fast
sudo yum install -y wget httpd-tools
```

Second, add repositories and install st2.
```shell
## NB! This step provides instructions for centos7 distro
# Don't forget to use correct distro (el6 - for rhel6/centos6, and el7 - for rhel7/centos7)!
export DISTRO=el7
sudo wget https://bintray.com/stackstorm/${DISTRO}_staging/rpm -O /etc/yum.repos.d/bintray-stackstorm-${DISTRO}_staging.repo
# Fix to use the correct URL
sed -i "s|/${DISTRO}_staging|/${DISTRO}_staging/stable|" /etc/yum.repos.d/bintray-stackstorm-${DISTRO}_staging.repo
unset DISTRO

# Update repo and install st2
sudo yum install -y st2
```

## Install dependent services

St2 uses MongoDB database and RabbitMQ messaging queue, so we need to install these services. We suggest to use [IUS repo](https://ius.io/), it contains MongoDB and RabbitMQ. It's worth mentioning that IUS repo is *EPEL*-compatible, because EPEL comes as its part. So let's install the repo and proceed with the installation:

```
# Install IUS repo
wget -O - https://setup.ius.io/ | sudo bash -s

sudo yum install -y mongodb-server rabbitmq-server

# Allow localhost connections to rabbitmq
echo '[{rabbit, [{disk_free_limit, 10}, {loopback_users, []}]}].' | sudo tee /etc/rabbitmq/rabbitmq.config

# Make sure mongo has started and restart rabbitmq to pickup changes.
sudo systemctl start mongod
sudo systemctl restart rabbitmq-server

# NB! On el6 use sysv init commands, respectively.
# sudo /etc/init.d/mongod start
# sudo /etc/init.d/rabbitmq-server restart
```

## Install mistral (optional)

If you are planning to use mistral workflows follow the provided instructions otherwise you can ignore them.

First you need to choose what PostgreSQL version you want to use. Since we are installing st2 on Centos 7 (in the current example). We will use the following [link](http://yum.postgresql.org/9.5/redhat/rhel-7-x86_64/pgdg-centos95-9.5-2.noarch.rpm). (For Centos 6,  you may use this [link](http://yum.postgresql.org/9.5/redhat/rhel-6-x86_64/pgdg-centos95-9.5-2.noarch.rpm)).
*Make sure you have chosen the correct distro and arch, follow this [__instructions__](http://yum.postgresql.org/) to locate the desired repo*. As you find the required URL substitute it into the command bellow:

```shell
# NB! Repo creation link for Cento 7.
sudo yum install -y http://yum.postgresql.org/9.5/redhat/rhel-7-x86_64/pgdg-centos95-9.5-2.noarch.rpm
```

Consult to https://wiki.postgresql.org/wiki/YUM_Installation on how to disable postgres from the default repository. For our case which is Centos, we need to update `/etc/yum.repos.d/CentOS-Base.repo` file **[base]** and **[updates]** sections with the following contents:

```
exclude=postgresql*
```

Proceed with installing postgres database and mistral:

```shell
sudo yum install -y postgresql95-server st2mistral
# Initialize data base
sudo /usr/pgsql-9.5/bin/postgresql95-setup initdb

# Make localhost connections to use an MD5-encrypted password for authentication
sudo sed -i "s/\(host.*all.*all.*127.0.0.1\/32.*\)ident/\1md5/" /var/lib/pgsql/9.5/data/pg_hba.conf
sudo sed -i "s/\(host.*all.*all.*::1\/128.*\)ident/\1md5/" /var/lib/pgsql/9.5/data/pg_hba.conf

# Apply the new settings (restart/start)
sudo systemctl restart postgresql-9.5

# NB! On el6 use sysv init
# sudo /etc/init.d/postgresql-9.5 restart
```

Create mistral user and database in postgres:
```
cat << EHD | sudo -u postgres psql
CREATE ROLE mistral WITH CREATEDB LOGIN ENCRYPTED PASSWORD 'StackStorm';
CREATE DATABASE mistral OWNER mistral;
EHD
```

Update schema and start mistral:
```
/opt/stackstorm/mistral/bin/mistral-db-manage --config-file /etc/mistral/mistral.conf upgrade head
/opt/stackstorm/mistral/bin/mistral-db-manage --config-file /etc/mistral/mistral.conf populate

sudo systemctl start mistral

# NB! On el6 use sysv init
# sudo /etc/init.d/mistral start
```

# Starting st2 and simple checks

Register content and start all st2 services:

```
st2-register-content --config-file=/etc/st2/st2.conf --register-all
sudo st2ctl start
```

Adding test user and setting up authentication token (make sure to use different credentials in production environment):
```
sudo htpasswd -cb /etc/st2/htpasswd test Ch@ngeMe
export ST2_AUTH_TOKEN=$(st2 auth test -p Ch@ngeMe -t)
```

Basic validation steps:
```
sudo st2ctl status
st2 action list
```
