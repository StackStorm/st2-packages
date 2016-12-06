# Core st2 installation

## Install repo tools
* sudo apt-get update
* sudo apt-get install -y software-properties-common

## Install tools
* sudo apt-get install -y apache2-utils

## Install Mongo
* sudo apt-get install -y mongodb-server

## Install rabbitmq
* sudo apt-get install -y rabbitmq-server

## Install st2
* wget -qO - https://bintray.com/user/downloadSubjectPublicKey?username=bintray | sudo apt-key add -
* sudo add-apt-repository 'deb https://dl.bintray.com/stackstorm/trusty_staging unstable main'
* sudo apt-get update
* sudo apt-get install -y st2bundle

## Setup auth user
* sudo htpasswd -cB /etc/st2/htpasswd admin

## Register content
* st2-register-content --config-file=/etc/st2/st2.conf --register-all

## start services
* sudo st2ctl start

## Basic validation
* export ST2_AUTH_TOKEN=\`st2 auth admin -p <PASSWORD> -t\`
* st2 action list

# Mistral installation

## Add st2 stable repo (XXX: This step would go away when st2 also switches to stable repo)

* sudo add-apt-repository 'deb https://dl.bintray.com/stackstorm/trusty_staging stable main'
* sudo apt-get update

## Install postgresql database
* sudo apt-get install -y postgresql
* sudo service postgresql start

## Create mistral user in postgres
* ```cat << EHD | sudo -u postgres psql
CREATE ROLE mistral WITH CREATEDB LOGIN ENCRYPTED PASSWORD 'StackStorm';
CREATE DATABASE mistral OWNER mistral;
EHD```

## Install mistral and st2mistral packages
* sudo apt-get install -y mistral st2mistral

## Create mistral config
* ```cat << EHD | sudo tee /etc/mistral/mistral.conf
[DEFAULT]
transport_url = rabbit://guest:guest@localhost:5672
[database]
connection = postgresql://mistral:StackStorm@localhost/mistral
max_pool_size = 50
[pecan]
auth_enable = false
EHD```

## Register st2mistral with mistral
* /usr/share/python/mistral/bin/mistral-db-manage --config-file /etc/mistral/mistral.conf populate

## Start mistral service
* sudo service mistral start

# UI installation

## Install nginx
* sudo apt-get install -y nginx

## Setup nginx configuration for st2web (FIX: These config files need to be hosted in st2web repo conf/samples/)
* wget https://raw.githubusercontent.com/enykeev/st2testground/master/conf/nginx/st2.conf
* sudo cp st2.conf /etc/nginx/sites-available/

## Setup SSL certs (self-signed)
* sudo mkdir -p /etc/ssl/st2
* sudo openssl req -x509 -newkey rsa:2048 -keyout /etc/ssl/st2/st2.key -out /etc/ssl/st2/st2.crt -days XXX -nodes -subj "/C=US/ST=California/L=Palo Alto/O=StackStorm/OU=Information Technology/CN=$(hostname)"

## Install st2web
* sudo apt-get install -y st2web

## Setup st2web configuration (FIX: These config files need to be hosted in st2web repo conf/samples/)
* wget https://raw.githubusercontent.com/enykeev/st2testground/master/conf/st2web/config.js
* sudo cp config.js /opt/stackstorm/static/webui/

## Restart st2 and UI
* sudo service nginx reload
* sudo st2ctl reload

## Validate UI works
* Open https://${ip-of-box}/ in browser, accept self signed certs if necessary and proceed to using UI.
