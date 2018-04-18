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
case "$1" in
  # Clean up cached Docker containers from the previous CircleCI build
  # With https://circleci.com/docs/2.0/docker-layer-caching/ and 'reusable: true' we may see
  # containers running from the previous cached build
  clean)
    echo Cleaning cached Docker containers which could be there from the previous build ...
    docker-compose -f docker-compose.circle2.yml -f docker-compose.override.yml rm -v --stop --force || true
  ;;
  # Perform fake command invocation, technically provides images "pull" phase.
  pull)
    echo Pulling dependent Docker images for $2 ...
    docker-compose -f docker-compose.circle2.yml -f docker-compose.override.yml pull --include-deps $2
  ;;
  build)
    echo Starting Packages Build for $2 ...
    docker-compose -f docker-compose.circle2.yml -f docker-compose.override.yml run \
        -e ST2_CHECKOUT=${ST2_CHECKOUT} \
        -e ST2_GITURL=${ST2_GITURL} \
        -e ST2_GITREV=${ST2_GITREV} \
        -e ST2_GITDIR=${ST2_GITDIR} \
        -e ST2PKG_VERSION=${ST2PKG_VERSION} \
        -e ST2PKG_RELEASE=${ST2PKG_RELEASE} \
        -e ST2MISTRAL_CHECKOUT=${ST2MISTRAL_CHECKOUT} \
        -e ST2MISTRAL_GITURL=${ST2MISTRAL_GITURL} \
        -e ST2MISTRAL_GITREV=${ST2MISTRAL_GITREV} \
        -e ST2MISTRAL_GITDIR=${ST2MISTRAL_GITDIR} \
        -e MISTRAL_VERSION=${MISTRAL_VERSION} \
        -e MISTRAL_RELEASE=${MISTRAL_RELEASE} \
        -e ST2_PACKAGES="${ST2_PACKAGES}" \
        -e ST2_CIRCLE_URL=${CIRCLE_BUILD_URL} \
        $2 build
  ;;
  test)
    [ "$TESTING" = 0 ] && { echo "Omitting Tests for $2 ..." ; exit 0; }
    echo Starting Tests for $2 ...
    docker-compose -f docker-compose.circle2.yml -f docker-compose.override.yml run \
        -e ST2_PACKAGES="${ST2_PACKAGES}" \
        $2 test
  ;;
esac
