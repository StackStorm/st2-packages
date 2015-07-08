#!/bin/sh

# This script builds/rebuilds containers and pushes them to remote registries.
# Examples:
#
# ./publish.sh -p quay.io/dennybaa/ droneunit-ubuntu              => quay.io/dennybaa/droneunit-ubuntu
# ./publish.sh --no-push -p quay.io/dennybaa/ $(ls -d */)         => builds all containers
# ./publish.sh -p quay.io/dennybaa/ droneunit/Dockerfile.debian   => quay.io/dennybaa/droneunit-debian
#

BUILD_OPTS=
TEMP=`getopt -o p: -l no-cache,no-push,rm -- "$@"`
parse_status=$?

usage() {
  echo "Usage: $0 [--no-cache --no-push --rm] [-p registry prefix path ] container[/Dockerfile.namesuffix] container[/Dockerfile.namesuffix] ..."
  echo "\t --no-cache - Do not use cache when building the image"
  echo "\t --no-push  - Do not publish into remote repository"
  echo "\t --rm       - Remove intermediate containers after a successful build" 
  echo
  echo "\t -p         - Path to remote registry including prefix, ex: quay.io/myusername/"
  echo
  echo "\t Containers found with path suffix (container/Dockerfile.debian) will be tagged using"
  echo "\t special pattern. Specifically for [-p quay.io/myusername/ myapp/Dockerfile.debian],"
  echo "\t the image will be tagged as quay.io/myusername/myapp-debian."
}


# parse check
[ "0" != $parse_status ] && { echo && usage && exit $parse_status; }

# extract options and their arguments into variables.
while true ; do
  case "$1" in
    -p)
      PREFIX_PATH=$2; shift 2;;
    --no-cache)
      BUILD_OPTS="${BUILD_OPTS} --no-cache"; shift;;
    --no-push)
      NO_PUSH=1; shift;;
    --rm)
      BUILD_OPTS="${BUILD_OPTS} --rm"; shift;;

    *) break;;
  esac
done

# check containers list
CONTAINERS=$@
[ $(echo ${CONTAINERS} | wc -w) = 0 ] && { usage && exit 1; }

# Execute builds
for cpath in $CONTAINERS; do
  # get contianer base container[/Dockerfile.debian] => container
  c=$(echo $cpath | cut -f1 -d\/)
  # get optional /Dockerfile.debian without /
  dockerfile=$(echo ${cpath#$c} | sed -r 's/\/+//')

  if [ ! -z "$dockerfile" ]; then
    BUILD_OPTS="${BUILD_OPTS} -f ${c}/${dockerfile}"
    suffix="-$(echo $dockerfile | cut -f2 -d.)"
  else
    BUILD_OPTS="${BUILD_OPTS} -f ${c}/Dockerfile"
  fi

  echo "Building: ${PREFIX_PATH}${c}${suffix}    (at $(pwd))"
  echo '========='

  docker build ${BUILD_OPTS} -t ${PREFIX_PATH}${c}${suffix} ./ || continue

  # push is required
  [ "$NO_PUSH" != 1 ] && docker push ${PREFIX_PATH}${c}${suffix}
done
