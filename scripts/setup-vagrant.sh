#!/bin/bash

set -e

fail() {
  exit 2
}

trap 'fail' EXIT

case $ST2_TARGET in
  "el7")
    DC_TARGET=centos7
    INSTALL_CMD="yum";;
  "focal"|"bionic")
    DC_TARGET=$ST2_TARGET
    INSTALL_CMD="apt-get";;
  *)
    echo "[Error] Unknown target $ST2_TARGET"
    exit 1;;
esac

echo "[Install] dependencies"
sudo $INSTALL_CMD update
if [[ $ST2_TARGET != 'el7' ]]; then
  sudo apt-get -y autoremove
  sudo apt-get install -y gdebi-core
fi

sudo $INSTALL_CMD install -y git curl wget

# Install docker-compose
DC_BIN="/usr/local/bin/docker-compose"
DC_URL="https://github.com/docker/compose/releases/download/1.21.0/docker-compose-`uname -s`-`uname -m`"
if [[ ! -x $DC_BIN ]]; then
  echo "[Install] docker-compose $ST2_TARGET"
  sudo sh -c "curl -sL $DC_URL > $DC_BIN"
  sudo chmod +x $DC_BIN
fi

# Using docker-compose, 1) build packages, and 2) run quick tests
if [[ "${ST2_PACKAGES}" != "" ]]; then
  ST2PACKAGES="-e ST2_PACKAGES='$ST2_PACKAGES'"
fi
if [[ "${ST2_GITURL}" != "" ]]; then
  ST2URL="-e ST2_GITURL=$ST2_GITURL"
fi
if [[ "${ST2_GITREV}" != "" ]]; then
  ST2REV="-e ST2_GITREV=$ST2_GITREV"
fi
sudo sh -c "(cd /vagrant && $DC_BIN run $ST2PACKAGES $ST2URL $ST2REV --rm $ST2_TARGET)"

if [ "$ST2_INSTALL" = "yes" ]; then
  echo 'Install st2 packages'

  # Halt the docker test environment (otherwise, the subsequent self-verification will fail)
  sudo docker stop "vagrant_${DC_TARGET}test_1"

  # Install the packages we just built
  if [[ $ST2_TARGET != 'el7' ]]; then
    sudo /usr/bin/gdebi -n /tmp/st2-packages/st2_*.deb
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
    if [[ $ST2_TARGET != 'el7' ]]; then
      sudo $INSTALL_CMD install -y apache2-utils
    else
      sudo $INSTALL_CMD install -y httpd-tools
    fi
  fi

  HP='/etc/st2/htpasswd'
  if [[ ! -f "$HP" ]]; then
    echo $ST2_PASSWORD | sudo htpasswd -c -i $HP $ST2_USER
  else
    echo $ST2_PASSWORD | sudo htpasswd -i $HP $ST2_USER
  fi

  # Setup datastore encryption
  sudo sh -c 'cat <<EOF >> /etc/st2/st2.conf

[keyvalue]
encryption_key_path = /etc/st2/keys/datastore_key.json
EOF'

  sudo mkdir -p /etc/st2/keys
  sudo st2-generate-symmetric-crypto-key --key-path /etc/st2/keys/datastore_key.json

  # Start ST2 services
  sudo st2ctl start
  sudo st2ctl reload

  if [ "$ST2_VERIFY" = "yes" ]; then
    echo 'Running self-verification'
    sudo sh -c "export ST2_AUTH_TOKEN=`st2 auth $ST2_USER -p $ST2_PASSWORD -t` && /usr/bin/st2-self-check"
  fi
fi

trap - EXIT

exit 0
