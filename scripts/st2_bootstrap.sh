#!/bin/bash

install_dependencies() {
  sudo apt-get update
  sudo apt-get install -y mongodb-server rabbitmq-server postgresql
}

setup_repositories() {
  wget -qO - https://bintray.com/user/downloadSubjectPublicKey?username=bintray | sudo apt-key add -
  echo "deb https://dl.bintray.com/stackstorm/trusty_staging stable main" | sudo tee /etc/apt/sources.list.d/st2-stable.list
  sudo apt-get update
}

install_stackstorm_components() {
  sudo apt-get update
  sudo apt-get install -y st2 st2mistral
}

setup_mistral_database() {
  cat << EHD | sudo -u postgres psql
CREATE ROLE mistral WITH CREATEDB LOGIN ENCRYPTED PASSWORD 'StackStorm';
CREATE DATABASE mistral OWNER mistral;
EHD

  # Setup Mistral DB tables, etc.
  /opt/stackstorm/mistral/bin/mistral-db-manage --config-file /etc/mistral/mistral.conf upgrade head
  # Register mistral actions
  /opt/stackstorm/mistral/bin/mistral-db-manage --config-file /etc/mistral/mistral.conf populate
}

configure_ssh_and_sudo () {

  # Create an SSH system user
  sudo useradd stanley
  sudo mkdir -p /home/stanley/.ssh
  sudo chmod 0700 /home/stanley/.ssh

  # Generate ssh keys on StackStorm box and copy over public key into remote box.
  sudo ssh-keygen -f /home/stanley/.ssh/stanley_rsa -P ""
  #sudo cp ${KEY_LOCATION}/stanley_rsa.pub /home/stanley/.ssh/stanley_rsa.pub

  # Authorize key-base acces
  sudo cat /home/stanley/.ssh/stanley_rsa.pub >> /home/stanley/.ssh/authorized_keys
  sudo chmod 0600 /home/stanley/.ssh/authorized_keys
  sudo chown -R stanley:stanley /home/stanley

  # Enable passwordless sudo
  sudo echo "stanley    ALL=(ALL)       NOPASSWD: SETENV: ALL" >> /etc/sudoers.d/st2

  ##### NOTE STILL NEED ADJUST CONFIGURATION FOR ST2 USER SECTION #####
}

use_st2ctl() {
  sudo st2ctl $1
}

verify() {

  st2 --version || echo "Failed on st2 --version"
  st2 -h || echo "Failed on st2 -h"
  st2 action list --pack=core || echo "Failed on st2 action list"
  st2 run core.local -- date -R || echo "Failed on st2 run core.local -- date -R"
  st2 execution list || echo "Failed on st2 execution list"
  st2 run core.remote hosts="127.0.0.1" -- uname -a || echo "Failed on st2 run core.remote hosts="localhost" -- uname -a"
  st2 run packs.install packs=st2 || echo "Failed on st2 run packs.install packs=st2"

}

configure_authentication() {
  # Install htpasswd utility if you don't have it
  sudo apt-get install -y apache2-utils
  # Create a user record in a password file.
  echo "Ch@ngeMe" | sudo htpasswd -i /etc/st2/htpasswd test

  # Get an auth token and use in CLI or API
  st2 auth test || echo "Failed on st2 auth test"

  # A shortcut to authenticate and export the token
  export ST2_AUTH_TOKEN=$(st2 auth test -p Ch@ngeMe -t)

  # Check that it works
  st2 action list  || echo "Failed on st2 action list in Configure Authentication"
}

## Let's do this!

install_dependencies
setup_repositories
install_stackstorm_components
setup_mistral_database
configure_ssh_and_sudo
use_st2ctl start
use_st2ctl reload
verify
configure_authentication
