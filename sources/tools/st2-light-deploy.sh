#!/bin/bash
# All-in-one install

if [ -f /etc/debian_version ]
then
  DEBIAN=1
  PACKAGE_DEPS="rabbitmq-server mongodb"
fi

install_package_deps() {
  [ $DEBIAN -eq 1 ] && {
    echo "Installing StackStorm dependencies: ${PACKAGE_DEPS}"
    DEBIAN_FRONTEND="noninteractive" apt-get install -y ${PACKAGE_DEPS}
  }
}

# -- MAIN
install_package_deps
