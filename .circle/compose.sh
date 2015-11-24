#!/bin/bash
set -e

# Pass these ENV Variables for `docker-compose` to consume:
# ST2_GITURL -
# ST2_GITREV -
# ST2PKG_VERSION -
# ST2PKG_RELEASE -

# Usage:
# compose.sh pull wheezy - Pull dependant Docker Images
# compose.sh build wheezy - Build packages for specific distro
# compose.sh test wheezy - Perform Serverspec tests
case "$1" in
  pull)
    docker-compose -f compose.yml -f docker-compose.circle.yml run $2 'echo Pulling Docker Images'
  ;;
  build)
    docker-compose -f compose.yml -f docker-compose.circle.yml run $2
  ;;
  test)
    docker-compose -f compose.yml -f docker-compose.circle.yml run $2 bash -c 'cp /root/Gemfile* ./ && bundle exec rspec':
  ;;
esac
