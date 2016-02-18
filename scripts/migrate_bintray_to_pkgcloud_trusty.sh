#!/bin/bash

echo "Removing Bintray repo definitions from /etc/sources.list.d..."
BINTRAY_REPO=/etc/apt/sources.list.d/st2-staging-stable.list

if [ -f ${BINTRAY_REPO} ]; then
  echo "Found bintray definitons. Removing now..."
  sudo rm -f ${BINTRAY_REPO}
fi

key_exists=$(sudo apt-key list | grep -B 1 Bintray)
if [[ ! -z "$key_exists" ]]; then
  BINTRAY_KEY=$(sudo apt-key list | grep -B 1 Bintray | grep pub | awk '{print $2}' | cut -d '/' -f 2)
  echo "Deregistering Bintray GPG key ${BINTRAY_KEY}..."
  sudo apt-key del ${BINTRAY_KEY}
  if [[ $? != 0 ]]; then
    echo "Could not remove Bintray GPG key ${BINTRAY_REPO} from the box."
    echo "Registered keys are..."
    sudo apt-key list
  else
    echo "Removed Bintray GPG key successfully."
  fi
fi

echo "Adding back package cloud repo definitions to /etc/sources.list.d..."
curl -s https://packagecloud.io/install/repositories/StackStorm/staging-stable/script.deb.sh | sudo bash
