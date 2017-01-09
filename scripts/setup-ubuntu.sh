#!/bin/bash

TARGET=$1

# TODO: Assert TARGET is one of "trusty", and "xenial"

echo "[Install] dependencies"
sudo apt-get update

sudo apt-get install -y linux-image-extra-$(uname -r)
sudo apt-get install -y git curl wget

echo "[Install] docker-compose"
sudo sh -c 'curl -sL https://github.com/docker/compose/releases/download/1.9.0/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose'
sudo chmod +x /usr/local/bin/docker-compose

sudo sh -c "(cd /vagrant && /usr/local/bin/docker-compose run --rm ${TARGET})"

# TODO: Optionally install the packages we just built
# TODO: Optionally run self-verification

# TODO: Allow doing this for el6 el7 trusty xenial
