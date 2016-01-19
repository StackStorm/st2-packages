# Add EPEL repo
sudo yum install -y epel-release

# Install mongodb
sudo yum install -y mongodb mongodb-server

# Install rabbitmq
sudo rpm --import https://www.rabbitmq.com/rabbitmq-signing-key-public.asc
curl -sS -k -o /tmp/rabbitmq-server.rpm https://www.rabbitmq.com/releases/rabbitmq-server/v3.3.5/rabbitmq-server-3.3.5-1.noarch.rpm
sudo yum localinstall -y /tmp/rabbitmq-server.rpm

## Install st2
sudo touch /etc/yum.repos.d/StackStorm-el7_staging-unstable.repo

Add following lines to /etc/yum.repos.d/StackStorm-el7_staging-unstable.repo
[StackStorm-el7_staging-unstable]
name=StackStorm-el7_staging-unstable
baseurl=https://dl.bintray.com/stackstorm/el7_staging/unstable
enabled=1
gpgcheck=0

sudo yum install st2bundle

## Start mongodb
sudo systemctl start mongod

## Start rabbitmq
sudo systemctl start rabbitmq-server

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
