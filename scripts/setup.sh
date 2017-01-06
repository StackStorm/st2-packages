#!/bin/bash

echo "[Install] dependencies"
sudo yum update

sudo yum install -y linux-image-extra-$(uname -r)

sudo yum install -y git curl wget

echo "[Install] docker-compose"
sudo sh -c 'curl -sL https://github.com/docker/compose/releases/download/1.9.0/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose'
sudo chmod +x /usr/local/bin/docker-compose

sudo sh -c "(cd /vagrant && /usr/local/bin/docker-compose run --rm el7)"

# TODO: Optionally install the packages we just built
# TODO: Optionally run self-verification

# TODO: Allow doing this for el6 el7 trusty xenial
