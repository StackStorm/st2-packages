# Run as root
sudo su

## Install repo tools
apt-get update
apt-get install -y software-properties-common

## Install virtualenv
apt-get install -y python-pip
pip install --upgrade pip
pip install virtualenv
virtualenv --version (> 13.1.2)

## Install Mongo
apt-get install -y mongodb-server

## Install rabbitmq
apt-get install -y rabbitmq-server

## Install st2
wget -qO - https://bintray.com/user/downloadSubjectPublicKey?username=bintray | apt-key add -
add-apt-repository 'deb https://dl.bintray.com/stackstorm/trusty_staging unstable main'
apt-get update
apt-get install -y st2bundle

## Setup auth user
apt-get install -y apache2-utils
htpasswd -cs /etc/st2/htpasswd admin

## Register content
st2-register-content --config-file=/etc/st2/st2.conf --register-all

## start services
st2ctl start

## Basic validation
export ST2_AUTH_TOKEN=`st2 auth admin -p <PASSWORD> -t`
st2 action list

