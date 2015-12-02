#!/bin/bash
set -e
set -x

# Used for `RABBITMQHOST` `POSTGRESHOST` `MONGODBHOST`, see docker-compose.override.yml
HOST_IP=$(ifconfig docker0 | grep 'inet addr' | awk -F: '{print $2}' | awk '{print $1}')

# Pass these ENV Variables for `docker-compose` to consume:
# ST2_GITURL - st2 GitHub repository (ex: https://github.com/StackStorm/st2)
# ST2_GITREV - st2 branch name (ex: master, v1.2.1). This will be used to determine correct Docker Tag: `latest`, `1.2.1`
# ST2PKG_VERSION - st2 version, will be reused in Docker image metadata (ex: 1.2dev)
# ST2PKG_RELEASE - Release number aka revision number for `st2bundle` package, will be reused in Docker metadata (ex: 4)

# Usage:
# docker-compose.sh pull wheezy - Pull dependant Docker Images for wheezy
# docker-compose.sh build wheezy - Build packages for specific distro
# docker-compose.sh test wheezy - Perform Serverspec/Rspec tests for wheezy
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
        -e RABBITMQHOST=${HOST_IP} \
        -e POSTGRESHOST=${HOST_IP} \
        -e MONGODBHOST=${HOST_IP} \
        $2 build
  ;;
  test)
    re="\\b$2\\b"
    if [[ "${TESTING[@]}" =~ $re ]]; then
      echo Starting Tests for $2 ...
      docker-compose -f docker-compose.circle.yml run \
          -e ST2_GITURL=${ST2_GITURL} \
          -e ST2_GITREV=${ST2_GITREV} \
          -e ST2PKG_VERSION=${ST2PKG_VERSION} \
          -e ST2PKG_RELEASE=${ST2PKG_RELEASE} \
          -e RABBITMQHOST=${HOST_IP} \
          -e POSTGRESHOST=${HOST_IP} \
          -e MONGODBHOST=${HOST_IP} \
          $2 test
    else
      echo Omitting Tests for $2 ...
    fi
  ;;
esac
