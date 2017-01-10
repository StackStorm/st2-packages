#!/bin/bash

TARGET=$1

if [ "$TARGET" != "el7" ]; then
  echo "[Error] I only grok the 'el7' target"
  exit 1
fi

echo "[Install] dependencies"
sudo yum update

sudo yum install -y linux-image-extra-$(uname -r)
sudo yum install -y git curl wget

echo "[Install] docker-compose $TARGET"
sudo sh -c 'curl -sL https://github.com/docker/compose/releases/download/1.9.0/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose'
sudo chmod +x /usr/local/bin/docker-compose

sudo sh -c "(cd /vagrant && /usr/local/bin/docker-compose run --rm $TARGET)"

# TODO: Optionally install the packages we just built
sudo yum install -y /tmp/st2-packages/st2*.rpm

# TODO: Optionally run self-verification
