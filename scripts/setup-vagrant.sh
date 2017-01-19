#!/bin/bash

TARGET=$1
USER=$2
PASSWD=$3
INSTALL=$4
VERIFY=$5

case $TARGET in
  "el7")
    DCTARGET=centos7
    INSTALL_CMD="yum";;
  "trusty"|"xenial")
    DCTARGET=$TARGET
    INSTALL_CMD="apt-get";;
  *)
    echo "[Error] Unknown target $TARGET"
    exit 1;;
esac

echo "[Install] dependencies"
sudo $INSTALL_CMD update
if [[ $TARGET != 'el7' ]]; then
  sudo apt-get -y autoremove
fi

sudo $INSTALL_CMD install -y linux-image-extra-$(uname -r)
sudo $INSTALL_CMD install -y git curl wget

# Install docker-compose
DC="/usr/local/bin/docker-compose"
URL="https://github.com/docker/compose/releases/download/1.9.0/docker-compose-`uname -s`-`uname -m`"
if [[ ! -x $DC ]]; then
  echo "[Install] docker-compose $TARGET"
  sudo sh -c "curl -sL $URL > $DC"
  sudo chmod +x $DC
fi

# Using docker-compose, 1) build packages, and 2) run quick tests
sudo sh -c "(cd /vagrant && $DC run --rm $TARGET)"

if [ "$INSTALL" = "yes" ]; then
  echo 'Install st2 packages'

  # Halt the docker test environment (otherwise, the subsequent self-verification will fail)
  sudo docker stop "vagrant_${DCTARGET}test_1"

  # Install the packages we just built
  if [[ $TARGET != 'el7' ]]; then
    sudo sh -c '(cd /tmp/st2-packages && dpkg -i st2*.deb)'
    sudo sh -c "($INSTALL_CMD install -y -f)"
  else
    sudo $INSTALL_CMD install -y /tmp/st2-packages/st2*.rpm
  fi

  # Setup SSH keys and sudo access
  sudo mkdir -p /home/stanley/.ssh
  sudo chmod 0700 /home/stanley/.ssh

  sudo ssh-keygen -f /home/stanley/.ssh/stanley_rsa -P ""
  sudo sh -c 'cat /home/stanley/.ssh/stanley_rsa.pub >> /home/stanley/.ssh/authorized_keys'
  sudo chown -R stanley:stanley /home/stanley/.ssh

  sudo sh -c 'echo "stanley      ALL=(ALL)    NOPASSWD: SETENV: ALL" >> /etc/sudoers.d/st2'
  sudo chmod 0440 /etc/sudoers.d/st2

  sudo sed -i -r "s/^Defaults\s+\+?requiretty/# Defaults +requiretty/g" /etc/sudoers

  # Create htpasswd file
  HT='/usr/bin/htpasswd'
  if [[ ! -x "$HT" ]]; then
    if [[ $TARGET != 'el7' ]]; then
      sudo $INSTALL_CMD install -y apache2-utils
    else
      sudo $INSTALL_CMD install -y httpd-tools
    fi
  fi

  HP='/etc/st2/htpasswd'
  if [[ ! -f "$HP" ]]; then
    echo $PASSWD | sudo htpasswd -c -i $HP $USER
  else
    echo $PASSWD | sudo htpasswd -i $HP $USER
  fi

  # Setup datastore encryption
  sudo sh -c 'cat <<EOF >> /etc/st2/st2.conf

[keyvalue]
encryption_key_path = /etc/st2/keys/datastore_key.json
EOF'

  sudo mkdir -p /etc/st2/keys
  sudo st2-generate-symmetric-crypto-key --key-path /etc/st2/keys/datastore_key.json

  # Setup Mistral DB
  /opt/stackstorm/mistral/bin/mistral-db-manage --config-file /etc/mistral/mistral.conf upgrade head
  /opt/stackstorm/mistral/bin/mistral-db-manage --config-file /etc/mistral/mistral.conf populate

  # Start ST2 services
  sudo st2ctl start
  sudo st2ctl reload

  if [ "$VERIFY" = "yes" ]; then
    echo 'Running self-verification'
    sudo sh -c "export ST2_AUTH_TOKEN=`st2 auth $USER -p $PASSWD -t` && /usr/bin/st2-self-check"
  fi
fi
