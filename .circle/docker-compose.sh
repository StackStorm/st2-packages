#!/bin/bash
# Usage: docker-compose.sh OPERATION
#   This script is a st2 packages build pipeline invocation wrapper.
#
# Operations: 
#   pull, build and test operations are available. Which pull containers,
#   build and test packages respectivly.
#

set -e
# Source the build environment defintion (details in buildenv.sh)
. ~/.buildenv
set -x

# Used for `RABBITMQHOST` `POSTGRESHOST` `MONGODBHOST`, see docker-compose.override.yml
HOST_IP=$(ifconfig docker0 | grep 'inet addr' | awk -F: '{print $2}' | awk '{print $1}')

case "$1" in
  # Perform fake command invocation, technically provides images "pull" phase.
  pull)
    echo Pulling dependent Docker images for $DISTRO ...
    docker-compose -f docker-compose.circle.yml run \
        -e ST2_GITURL=${ST2_GITURL} \
        -e ST2_GITREV=${ST2_GITREV} \
        -e ST2PKG_VERSION=${ST2PKG_VERSION} \
        -e ST2PKG_RELEASE=${ST2PKG_RELEASE} \
        -e RABBITMQHOST=${HOST_IP} \
        -e POSTGRESHOST=${HOST_IP} \
        -e MONGODBHOST=${HOST_IP} \
        $DISTRO /bin/true
  ;;
  build)
    echo Starting Packages Build for $DISTRO ...
    docker-compose -f docker-compose.circle.yml run \
        -e ST2_GITURL=${ST2_GITURL} \
        -e ST2_GITREV=${ST2_GITREV} \
        -e ST2PKG_VERSION=${ST2PKG_VERSION} \
        -e ST2PKG_RELEASE=${ST2PKG_RELEASE} \
        -e RABBITMQHOST=${HOST_IP} \
        -e POSTGRESHOST=${HOST_IP} \
        -e MONGODBHOST=${HOST_IP} \
        $DISTRO build
  ;;
  test)
    [ "$TESTING" = 0 ] && { echo "Omitting Tests for $DISTRO ..." ; exit 0; }
    echo Starting Tests for $DISTRO ...
    docker-compose -f docker-compose.circle.yml run \
        -e ST2_GITURL=${ST2_GITURL} \
        -e ST2_GITREV=${ST2_GITREV} \
        -e ST2PKG_VERSION=${ST2PKG_VERSION} \
        -e ST2PKG_RELEASE=${ST2PKG_RELEASE} \
        -e RABBITMQHOST=${HOST_IP} \
        -e POSTGRESHOST=${HOST_IP} \
        -e MONGODBHOST=${HOST_IP} \
        $DISTRO test
  ;;
esac
