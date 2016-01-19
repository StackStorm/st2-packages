# Add EPEL repo
sudo yum install -y epel-release

# Install mongodb
sudo yum install -y mongodb mongodb-server

# Install rabbitmq
sudo rpm --import https://www.rabbitmq.com/rabbitmq-signing-key-public.asc
curl -sS -k -o /tmp/rabbitmq-server.rpm https://www.rabbitmq.com/releases/rabbitmq-server/v3.3.5/rabbitmq-server-3.3.5-1.noarch.rpm
sudo yum localinstall -y /tmp/rabbitmq-server.rpm

## Start mongodb
sudo systemctl start mongod

## Start rabbitmq
sudo systemctl status rabbitmq-server

## Install st2 (Fix this to use repo.)
wget https://bintray.com/artifact/download/stackstorm/el7_staging/unstable/st2bundle-1.3dev-67.x86_64.rpm
sudo yum localinstall -y st2bundle-1.3dev-67.x86_64.rpm

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
