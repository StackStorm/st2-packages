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

# Used for `RABBITMQHOST` `POSTGRESHOST` `MONGODBHOST`, see docker-compose.override.yml
HOST_IP=$(ifconfig docker0 | grep 'inet addr' | awk -F: '{print $2}' | awk '{print $1}')

set -x
case "$1" in
  # Perform fake command invocation, technically provides images "pull" phase.
  pull)
    echo Pulling dependent Docker images for $2 ...
    docker-compose -f docker-compose.circle.yml run \
        -e ST2_GITURL=${ST2_GITURL} \
        -e ST2_GITREV=${ST2_GITREV} \
        -e ST2PKG_VERSION=${ST2PKG_VERSION} \
        -e ST2PKG_RELEASE=${ST2PKG_RELEASE} \
        -e RABBITMQHOST=${HOST_IP} \
        -e POSTGRESHOST=${HOST_IP} \
        -e MONGODBHOST=${HOST_IP} \
        $2 /bin/true
  ;;
  build)
    echo Starting Packages Build for $2 ...
    docker-compose -f docker-compose.circle.yml run \
        -e ST2_GITURL=${ST2_GITURL} \
        -e ST2_GITREV=${ST2_GITREV} \
        -e ST2PKG_VERSION=${ST2PKG_VERSION} \
        -e ST2PKG_RELEASE=${ST2PKG_RELEASE} \
        -e ST2MISTRAL_GITURL=${ST2MISTRAL_GITURL} \
        -e ST2MISTRAL_GITREV=${ST2MISTRAL_GITREV} \
        -e MISTRAL_VERSION=${MISTRAL_VERSION} \
        -e MISTRAL_RELEASE=${MISTRAL_RELEASE} \
        -e RABBITMQHOST=${HOST_IP} \
        -e POSTGRESHOST=${HOST_IP} \
        -e MONGODBHOST=${HOST_IP} \
        -e ST2_PACKAGES="${ST2_PACKAGES}" \
        $2 build
  ;;
  test)
    [ "$TESTING" = 0 ] && { echo "Omitting Tests for $2 ..." ; exit 0; }
    echo Starting Tests for $2 ...
    docker-compose -f docker-compose.circle.yml run \
        -e ST2_GITURL=${ST2_GITURL} \
        -e ST2_GITREV=${ST2_GITREV} \
        -e ST2PKG_VERSION=${ST2PKG_VERSION} \
        -e ST2PKG_RELEASE=${ST2PKG_RELEASE} \
        -e ST2_WAITFORSTART=${ST2_WAITFORSTART} \
        -e RABBITMQHOST=${HOST_IP} \
        -e POSTGRESHOST=${HOST_IP} \
        -e MONGODBHOST=${HOST_IP} \
        $2 test
  ;;
esac
