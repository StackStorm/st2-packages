#!/bin/bash
set -e

# DEB / RPM
if [ -f /etc/debian_version ]; then
  export DEBIAN_FRONTEND=noninteractive
  PKGINST="sudo -E apt-get -qy install"
  DEPS="rabbitmq-server mongodb-server"

  [ "$MISTRAL_DISABLED" = 1 ] || DEPS="${DEPS} mysql-server"
else
  exit 1
fi


echo "===> Installing all st2 standalone dependencies"
$PKGINST $DEPS
