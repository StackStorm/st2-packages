# Installing st2 on debian/ubuntu

Follow this guide and we'll lead through the basic installation and setup steps.

## Setting up repos and fetching required software

First let's update the system and fetch software which will be required during installation and setup process:
```shell
sudo apt-get update
sudo apt-get install -y wget apache2-utils apt-transport-https sysvinit-utils
```

Second, add repositories and install st2.
```shell
## NB! This step provides instructions for ubuntu trusty
# Don't forget to use correct distro name!
export DISTRO=trusty

wget -qO - https://bintray.com/user/downloadSubjectPublicKey?username=bintray | sudo apt-key add -

echo "deb https://dl.bintray.com/stackstorm/${DISTRO}_staging stable main" | sudo tee /etc/apt/sources.list.d/st2-stable.list
unset DISTRO

# Update repo and install st2
sudo apt-get update && sudo apt-get install -y st2bundle
```

## Install dependent services

St2 uses MongoDB database and RabbitMQ messaging queue, so we need to install this services.
```
sudo apt-get install -y mongodb-server rabbitmq-server

# Allow localhost connections to rabbitmq
echo '[{rabbit, [{disk_free_limit, 10}, {loopback_users, []}]}].' | sudo tee /etc/rabbitmq/rabbitmq.config

# Make sure mongo has started and restart rabbitmq to pickup changes.
sudo service mongodb start
sudo service rabbitmq-server restart
```

## Install mistral (optional)

If you are planning to use mistral workflows follow the provided instructions otherwise you can ignore them.

Install postgres database and mistral:
```shell
sudo apt-get install -y postgresql st2mistral
sudo service postgresql start
```

Populate mistral configuration file:
```
## Create config
cat << EHD | sudo tee /etc/mistral/mistral.conf
[DEFAULT]
transport_url = rabbit://guest:guest@localhost:5672
[database]
connection = postgresql://mistral:StackStorm@localhost/mistral
max_pool_size = 50
[pecan]
auth_enable = false
EHD
```

Create mistral user and database in postgres:
```
cat << EHD | sudo -u postgres psql
CREATE ROLE mistral WITH CREATEDB LOGIN ENCRYPTED PASSWORD 'StackStorm';
CREATE DATABASE mistral OWNER mistral;
EHD
```

Start mistral and update schema:
```
sudo service mistral start
/usr/share/python/mistral/bin/mistral-db-manage --config-file /etc/mistral/mistral.conf populate
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
