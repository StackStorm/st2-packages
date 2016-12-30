#!/bin/bash

COMPOSE_DIR=$1
INSTALL_PKG=$2

echo "[Install] dependencies"
sudo yum install -y git curl wget

echo "[Install] docker"
sudo yum update

sudo yum install -y linux-image-extra-$(uname -r)

sudo tee /etc/yum.repos.d/docker.repo <<-'EOF'
[dockerrepo]
name=Docker Repository
baseurl=https://yum.dockerproject.org/repo/main/centos/7/
enabled=1
gpgcheck=1
gpgkey=https://yum.dockerproject.org/gpg
EOF

sudo yum install -y docker-engine

echo "[Usermod] Add vagrant user to docker group"
sudo usermod -a -G docker vagrant

sudo systemctl enable docker.service
sudo systemctl start docker

echo "[Install] docker-compose"
sudo sh -c 'curl -sL https://github.com/docker/compose/releases/download/1.9.0/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose'
sudo chmod +x /usr/local/bin/docker-compose

sleep 10

sudo sh -c "(cd ${COMPOSE_DIR} && /usr/local/bin/docker-compose run --rm el7)"

# TODO: Optionally install the packages we just built
# TODO: Optionally run self-verification

# TODO: Allow doing this for el6 el7 trusty xenial
