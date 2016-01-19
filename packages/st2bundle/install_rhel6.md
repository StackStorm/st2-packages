## Install IUS repo
sudo yum install -y https://dl.iuscommunity.org/pub/ius/stable/Redhat/6/x86_64/ius-release-1.0-14.ius.el6.noarch.rpm

# Install mongodb
sudo yum install -y mongodb mongodb-server

# Install rabbitmq
sudo rpm --import https://www.rabbitmq.com/rabbitmq-signing-key-public.asc
curl -sS -k -o /tmp/rabbitmq-server.rpm https://www.rabbitmq.com/releases/rabbitmq-server/v3.3.5/rabbitmq-server-3.3.5-1.noarch.rpm
sudo yum localinstall -y /tmp/rabbitmq-server.rpm

## Install st2 (Fix this to use repo.)
wget https://bintray.com/artifact/download/stackstorm/el6_staging/unstable/st2bundle-1.3dev-2.x86_64.rpm
sudo yum localinstall -y st2bundle-1.3dev-2.x86_64.rpm

## Start mongodb
sudo chkconfig mongod on
sudo service mongod start

## Start rabbitmq
sudo chkconfig rabbitmq-server on
sudo service rabbitmq-server start

