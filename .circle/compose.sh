#!/bin/bash

set -e

DISTROS=(wheezy jessie trusty centos7)
B_IDX=$CIRCLE_NODE_INDEX

# First invocation, so we need to install pip modules.
if (! pip show docker-compose &>/dev/null); then
  sudo pip install wheel
  sudo pip install docker-compose
fi

# Run compose only if args provided, otherwise just the code above
# will be executed.
if [ $# -gt 0 ]; then
  docker-compose -f compose.yml -f docker-compose.circle.yml ${DISTROS[$B_IDX]} "$@"
fi
