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
* export ST2_AUTH_TOKEN=`st2 auth admin -p <PASSWORD> -t`
* st2 action list
