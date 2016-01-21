# Add EPEL repo
* sudo yum install -y epel-release

# Install tools
* sudo yum install -y httpd-tools

# Install mongodb
* sudo yum install -y mongodb mongodb-server

# Install rabbitmq
* sudo yum install -y rabbitmq-server

## Install st2
* cat << EHD | sudo tee /etc/yum.repos.d/bintray-stackstorm-el6_staging_unstable.repo
[bintraybintray-stackstorm-el6_staging]
name=bintray-stackstorm-el6_staging
baseurl=https://dl.bintray.com/stackstorm/el6_staging/unstable
gpgcheck=0
enabled=1
EHD

* sudo yum install st2bundle

## Start mongodb
* sudo /etc/init.d/mongod start

## Start rabbitmq
* sudo /etc/init.d/rabbitmq-server start

## Start st2 services
* sudo st2ctl start

## Register content
* st2-register-content --config-file=/etc/st2/st2.conf --register-all

## Setup auth user
* sudo htpasswd -c /etc/st2/htpasswd admin

## Minimal validation
* export ST2_AUTH_TOKEN=`st2 auth admin -p <PASSWORD_USED_IN_HTPASSWD> -t`
* st2 action list
