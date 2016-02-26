# Installing st2 on debian/ubuntu

Follow this guide and we'll lead you through the basic installation and setup steps.

## Setting up repos and fetching required software

First let's update the system and fetch software which will be required during installation and setup process:
```shell
sudo apt-get update
sudo apt-get install -y wget curl apache2-utils apt-transport-https sysvinit-utils
```

Second, add repositories and install st2.
```shell
# Setup st2 repository
curl -s https://packagecloud.io/install/repositories/StackStorm/staging-stable/script.deb.sh | sudo bash

# Update repo and install st2
sudo apt-get update && sudo apt-get install -y st2
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
sudo service mistral start
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
