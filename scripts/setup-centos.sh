#!/bin/bash

TARGET=$1

# TODO: Assert TARGET is one of "el6" and "el7"

echo "[Install] dependencies"
sudo yum update

sudo yum install -y linux-image-extra-$(uname -r)
sudo yum install -y git curl wget

echo "[Install] docker-compose"
if [ "$TARGET" = "el6" ]; then
  # el6 does not work with docker-compose 1.4+
  sudo sh -c 'curl -sL https://github.com/docker/compose/releases/download/1.4.0/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose'
else
  sudo sh -c 'curl -sL https://github.com/docker/compose/releases/download/1.9.0/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose'
fi
sudo chmod +x /usr/local/bin/docker-compose

echo "(cd /vagrant && /usr/local/bin/docker-compose run --rm $TARGET)"
sudo sh -c "(cd /vagrant && /usr/local/bin/docker-compose run --rm $TARGET)"

# TODO: Optionally install the packages we just built
# TODO: Optionally run self-verification

# TODO: Allow doing this for el6 el7 trusty xenial
