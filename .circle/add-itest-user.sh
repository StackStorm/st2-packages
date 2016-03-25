#!/bin/bash
set -e

# Create an SSH system user (default `stanley` user may be already created)
if (! id stanley 2>/dev/null); then
  sudo useradd stanley
fi

sudo mkdir -p /home/stanley/.ssh

# Generate ssh keys on StackStorm box and copy over public key into remote box.
sudo ssh-keygen -f /home/stanley/.ssh/stanley_rsa -P ""
#sudo cp ${KEY_LOCATION}/stanley_rsa.pub /home/stanley/.ssh/stanley_rsa.pub

# Authorize key-base acces
sudo sh -c 'cat /home/stanley/.ssh/stanley_rsa.pub >> /home/stanley/.ssh/authorized_keys'
sudo chmod 0600 /home/stanley/.ssh/authorized_keys
sudo chmod 0700 /home/stanley/.ssh
sudo chown -R stanley:stanley /home/stanley

# Enable passwordless sudo
sudo sh -c 'echo "stanley    ALL=(ALL)       NOPASSWD: SETENV: ALL" >> /etc/sudoers.d/st2'
sudo chmod 0440 /etc/sudoers.d/st2
