#!/bin/bash

# Requires: `jq` binary

# Pass these ENV Variables
# CIRCLECI_ORGANIZATION - Packagecloud organization (default is stackstorm)
# CIRCLECI_TOKEN - act as a password for REST authentication

# Usage:
# packagecloud.sh build st2-dockerfiles master
function main() {
  : ${CIRCLECI_ORGANIZATION:=stackstorm}
  : ${CIRCLECI_TOKEN:? CIRCLECI_TOKEN env is required}

  case "$1" in
    build)
      build "${@:2}"
      ;;
    *)
      echo $"Usage: build st2-dockerfiles master"
      exit 1
  esac
}

# Arguments
# $1 CIRCLECI_PROJECT - CircleCI repository to build
# $2 CIRCLECI_BRANCH - specific branch to build
function build() {
  CIRCLECI_PROJECT=$1
  CIRCLECI_BRANCH=$2
  : ${CIRCLECI_PROJECT:? CIRCLECI_PROJECT (first arg) is required}
  : ${CIRCLECI_BRANCH:? CIRCLECI_BRANCH (second arg) is required}

  shift 2

  while [[ $# > 0 ]]; do
    key="$1"

    case $key in
        -c|--components)
        COMPONENTS="$2"
        shift # past argument
        ;;
        -r|--revision)
        REVISION="$2"
        shift # past argument
        ;;
        *)
          # unknown option
        ;;
    esac
    shift # past argument or value
  done

  params="{}"

  if [ -n "$COMPONENTS" ]; then
    params=$(echo $params | jq -r "setpath([\"build_parameters\", \"ST2_COMPONENTS\"]; \"$COMPONENTS\")")
  fi

  if [ -n "$REVISION" ]; then
    params=$(echo $params | jq -r "setpath([\"revision\"]; \"$REVISION\")")
  fi

  curl -X POST --header "Content-Type: application/json" -d $params https://circleci.com/api/v1/project/$CIRCLECI_ORGANIZATION/$CIRCLECI_PROJECT/tree/$CIRCLECI_BRANCH?circle-token=$CIRCLECI_TOKEN
}

main "$@"
