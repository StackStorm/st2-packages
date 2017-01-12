#!/bin/bash

TARGET=$1
USER=$2
PASSWD=$3
INSTALL=$4
VERIFY=$5

echo "TARGET=$TARGET"
echo "INSTALL=$INSTALL"
echo "VERIFY=$VERIFY"

# echo "[Install] dependencies"
# sudo apt-get update

# Ensure the latest dependencies are installed
# sudo apt-get install -y linux-image-extra-$(uname -r)
# sudo apt-get install -y git curl wget

# Install docker-compose
DC="/usr/local/bin/docker-compose"
if [[ ! -x $DC ]]; then
  echo "[Install] docker-compose $TARGET"
  sudo sh -c 'curl -sL https://github.com/docker/compose/releases/download/1.9.0/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose'
  sudo chmod +x $DC
fi

sudo sh -c "(cd /vagrant && /usr/local/bin/docker-compose run --rm $TARGET)"

if [ "$INSTALL" = "yes" ]; then
  # Install the packages we just built
  echo 'Install st2 packages'
  sudo sh -c '(cd /tmp/st2-packages && dpkg -i st2*.deb)'
  sudo sh -c '(apt-get install -y -f)'

  HT='/usr/bin/htpasswd'
  if [[ ! -x "$HT" ]]; then
    sudo apt-get install -y apache2-utils
  fi

  HP='/etc/st2/htpasswd'
  echo $PASSWD | sudo htpasswd -i $HP $USER

  sudo sh -c 'st2ctl restart'

  if [ "$VERIFY" = "yes" ]; then
    echo 'Running self-verification'
    sudo sh -c 'export ST2_AUTH_TOKEN=`st2 auth st2admin -p Ch@ngeMe -t` && /usr/bin/st2-self-check'
  fi
fi
