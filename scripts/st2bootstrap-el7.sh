#!/bin/bash

set -eux

# Note that default SELINUX policies for RHEL7 differ with CentOS7. CentOS7 is more permissive by default
# Note that depending on distro assembly/settings you may need more rules to change
# Apply these changes OR disable selinux in /etc/selinux/config (manually)
adjust_selinux_policies() {
  if getenforce | grep -q 'Enforcing'; then
    # Allow rabbitmq to use '25672' port, otherwise it will fail to start
    semanage port --list | grep -q 25672 || semanage port -a -t amqp_port_t -p tcp 25672

    # Allow network access for nginx
    setsebool -P httpd_can_network_connect 1
  fi
}

install_st2_dependencies() {
  sudo yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
  sudo yum -y install mongodb-server rabbitmq-server
  sudo systemctl start mongod rabbitmq-server
}

install_st2() {
  curl -s https://packagecloud.io/install/repositories/StackStorm/staging-stable/script.rpm.sh | sudo bash
  sudo yum -y install st2
  sudo st2ctl reload
  sudo st2ctl start
}

configure_st2_user() {
  # Create an SSH system user (default `stanley` user may be already created)
  if (! id stanley 2>/dev/null); then
    sudo useradd stanley
  fi
  
  sudo mkdir -p /home/stanley/.ssh
  sudo chmod 0700 /home/stanley/.ssh
  
  # On StackStorm host, generate ssh keys
  sudo ssh-keygen -f /home/stanley/.ssh/stanley_rsa -P ""
  
  # Authorize key-base acces
  sudo cat /home/stanley/.ssh/stanley_rsa.pub >> /home/stanley/.ssh/authorized_keys
  sudo chmod 0600 /home/stanley/.ssh/authorized_keys
  sudo chown -R stanley:stanley /home/stanley
  
  # Enable passwordless sudo
  sudo echo "stanley    ALL=(ALL)       NOPASSWD: SETENV: ALL" >> /etc/sudoers.d/st2
  sudo chmod 0440 /etc/sudoers.d/st2
  
  # Make sure `Defaults requiretty` is disabled in `/etc/sudoers`
  sudo sed -i "s/^Defaults\s\+requiretty/# Defaults requiretty/g" /etc/sudoers
}

configure_st2_authentication() {
  # Install htpasswd and tool for editing ini files
  sudo yum -y install httpd-tools crudini

  # Create a user record in a password file.
  echo "test_password" | sudo htpasswd -i /etc/st2/htpasswd test_user

  # Configure [auth] section in st2.conf
  crudini --set /etc/st2/st2.conf auth enable 'True'
  crudini --set /etc/st2/st2.conf auth backend 'flat_file'
  crudini --set /etc/st2/st2.conf auth backend_kwargs '{"file_path": "/etc/st2/htpasswd"}'
  
  sudo st2ctl restart-component st2api
}

verify_st2() {
  st2 --version
  st2 -h
  
  st2 auth test_user -p test_password
  # A shortcut to authenticate and export the token
  export ST2_AUTH_TOKEN=$(st2 auth test_user -p test_password -t)
  
  # List the actions from a 'core' pack
  st2 action list --pack=core
  
  # Run a local shell command
  st2 run core.local -- date -R
  
  # See the execution results
  st2 execution list
  
  # Fire a remote comand via SSH (Requires passwordless SSH)
  st2 run core.remote hosts='localhost' -- uname -a
  
  # Install a pack
  st2 run packs.install packs=st2
}

install_st2mistral_depdendencies() {
  sudo yum -y install postgresql-server postgresql-contrib postgresql-devel
  
  # Setup postgresql at a first time
  sudo postgresql-setup initdb

  # Make localhost connections to use an MD5-encrypted password for authentication
  sudo sed -i "s/\(host.*all.*all.*127.0.0.1\/32.*\)ident/\1md5/" /var/lib/pgsql/data/pg_hba.conf
  sudo sed -i "s/\(host.*all.*all.*::1\/128.*\)ident/\1md5/" /var/lib/pgsql/data/pg_hba.conf

  # Start PostgreSQL service
  sudo systemctl start postgresql

  cat << EHD | sudo -u postgres psql
CREATE ROLE mistral WITH CREATEDB LOGIN ENCRYPTED PASSWORD 'StackStorm';
CREATE DATABASE mistral OWNER mistral;
EHD
}

install_st2mistral() {
  # install mistral
  sudo yum -yq install st2mistral
  
  # Setup Mistral DB tables, etc.
  /opt/stackstorm/mistral/bin/mistral-db-manage --config-file /etc/mistral/mistral.conf upgrade head
  # Register mistral actions
  /opt/stackstorm/mistral/bin/mistral-db-manage --config-file /etc/mistral/mistral.conf populate

  # start mistral
  sudo systemctl start mistral
}

verify_st2mistral() {
  mistral --version

  cp -rf /usr/share/doc/st2/examples /opt/stackstorm/packs
  st2ctl reload
  
  # run mistral examples
  st2 run examples.mistral_examples
}

install_st2web() {
  # Install st2web and nginx
  sudo yum install -y st2web nginx
  
  # Generate self-signed certificate or place your existing certificate under /etc/ssl/st2
  sudo mkdir -p /etc/ssl/st2
  
  sudo openssl req -x509 -newkey rsa:2048 -keyout /etc/ssl/st2/st2.key -out /etc/ssl/st2/st2.crt \
  -days 365 -nodes -subj "/C=US/ST=California/L=Palo Alto/O=StackStorm/OU=Information Technology/CN=$(hostname)"
  
  # Copy and enable StackStorm's supplied config file
  sudo cp /usr/share/doc/st2/conf/nginx/st2.conf /etc/nginx/conf.d/
  
  # Disable default_server configuration in existing /etc/nginx/nginx.conf
  sudo sed -i 's/default_server//g' /etc/nginx/nginx.conf
  
  sudo systemctl restart nginx
}

verify_st2web() {
  # dumb check that st2web index.html works
  curl --insecure -s "https://127.0.0.1/" | grep -q "stackstorm"

  # st2auth check
  curl -X OPTIONS -I --insecure https://127.0.0.1/auth/ | grep -q 'St2-Api-Key'

  # st2api check
  curl -X OPTIONS -I --insecure https://127.0.0.1/api/ | grep -q 'St2-Api-Key'
}


adjust_selinux_policies

install_st2_dependencies
install_st2
configure_st2_user
configure_st2_authentication
verify_st2

install_st2mistral_depdendencies
install_st2mistral
verify_st2mistral

install_st2web
verify_st2web

echo -e "\033[32m Done"
