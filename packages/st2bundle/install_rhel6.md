## Install IUS repo
sudo yum install -y https://dl.iuscommunity.org/pub/ius/stable/Redhat/6/x86_64/ius-release-1.0-14.ius.el6.noarch.rpm

# Install mongodb
sudo yum install -y mongodb mongodb-server

# Install rabbitmq
sudo rpm --import https://www.rabbitmq.com/rabbitmq-signing-key-public.asc
curl -sS -k -o /tmp/rabbitmq-server.rpm https://www.rabbitmq.com/releases/rabbitmq-server/v3.3.5/rabbitmq-server-3.3.5-1.noarch.rpm
sudo yum localinstall -y /tmp/rabbitmq-server.rpm

## Install st2 (Fix this to use repo.)
sudo touch /etc/yum.repos.d/StackStorm-el6_staging-unstable.repo

Add following lines to /etc/yum.repos.d/StackStorm-el6_staging-unstable.repo
[StackStorm-el6_staging-unstable]
name=StackStorm-el6_staging-unstable
baseurl=https://dl.bintray.com/stackstorm/el6_staging/unstable
enabled=1
gpgcheck=0

sudo yum install st2bundle


## Start mongodb
sudo chkconfig mongod on
sudo service mongod start

## Start rabbitmq
sudo chkconfig rabbitmq-server on
sudo service rabbitmq-server start

## Start st2 services
sudo st2ctl start

## Register content
st2-register-content --config-file=/etc/st2/st2.conf --register-all

## Setup auth user
sudo yum install httpd-tools
sudo htpasswd -cs /etc/st2/htpasswd admin

## Install git (Fix st2bundle to require git.)
sudo yum install git-all

## Minimal validation
export ST2_AUTH_TOKEN=`st2 auth admin -p <PASSWORD_USED_IN_HTPASSWD> -t`
st2 action list
