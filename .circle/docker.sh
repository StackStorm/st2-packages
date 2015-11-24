#!/bin/bash
set -e

# Pass these ENV Variables for `docker` to consume:
# DOCKER_USER -
# DOCKER_EMAIL -
# DOCKER_PASSWORD -
# DOCKER_TAG -

# Usage:
# docker.sh build -
# docker.sh run
# docker.sh test -
# docker.sh push -

cd st2-dockerfiles

case "$1" in
  build)
    for dir in st2*/; do
      docker build -t stackstorm/${dir%*/}:${DOCKER_TAG} ${dir}
    done
  ;;
  run)
    docker run --name st2bundle -d st2bundle:${DOCKER_TAG}
  ;;
  test)
    # Verify Container by running `st2` command in it
    # Same as: docker exec st2docker st2 --version
    # See: https://circleci.com/docs/docker#docker-exec
    sudo lxc-attach -n "$(docker inspect --format '{{.Id}}' st2bundle)" -- bash -c 'st2 --version'
  ;;
  push)
    docker login -e ${DOCKER_EMAIL} -u ${DOCKER_USER} -p ${DOCKER_PASSWORD}
    for dir in st2*/; do
      docker push stackstorm/${dir%*/}:${DOCKER_TAG}
    done
  ;;
esac
