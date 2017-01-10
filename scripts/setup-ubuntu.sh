#!/bin/bash

TARGET=$1

echo "[Install] dependencies"
sudo apt-get update

# Ensure the dependencies are installed
sudo apt-get install -y linux-image-extra-$(uname -r)
sudo apt-get install -y git curl wget

# Install docker-compose
echo "[Install] docker-compose $TARGET"
sudo sh -c 'curl -sL https://github.com/docker/compose/releases/download/1.9.0/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose'
sudo chmod +x /usr/local/bin/docker-compose

sudo sh -c "(cd /vagrant && /usr/local/bin/docker-compose run --rm $TARGET)"

# TODO: Optionally install the packages we just built
sudo sh -c '(cd /tmp/st2-packages && dpkg -i st2*.deb)'
sudo sh -c '(apt-get install -y -f)'

# TODO: Optionally run self-verification
