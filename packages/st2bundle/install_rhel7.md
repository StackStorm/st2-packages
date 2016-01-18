# Add EPEL repo
sudo yum install -y epel-release

# Install mongodb 
sudo yum install -y mongodb mongodb-server

# install rabbitmq
sudo rpm --import https://www.rabbitmq.com/rabbitmq-signing-key-public.asc
curl -sS -k -o /tmp/rabbitmq-server.rpm https://www.rabbitmq.com/releases/rabbitmq-server/v3.3.5/rabbitmq-server-3.3.5-1.noarch.rpm
sudo yum localinstall -y /tmp/rabbitmq-server.rpm

## start mongodb
sudo systemctl start mongod

## start rabbitmq
sudo systemctl status rabbitmq-server

## start st2 services
sudo systemctl start st2api st2actionrunner st2auth st2sensorcontainer st2rulesengine st2notifier
 
## install htpasswd utility
sudo yum install httpd-tools
