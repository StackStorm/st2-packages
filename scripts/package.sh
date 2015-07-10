#!/bin/bash

set -e

export WHEELDIR=/tmp/wheelhouse
export DEBUG=1

# st2common package not included
PACKAGES="st2actions st2api st2auth st2client st2reactor"
PACKAGES_TO_BUILD="${@:-${PACKAGES}}"
ST2_GITURL="${ST2_GITURL:-https://github.com/StackStorm/st2}"
ST2_GITREV="${ST2_GITREV:-master}"
GITDIR=code
GITUPDATE=sources

# DEB / RPM
if [ -f /etc/debian_version ]; then
  BUILD_DEB=1
else
  BUILD_RPM=1
fi


# Package build function
build_package() {
  # check package directory
  if [ ! -d $pkg ]; then
    echo "Package directory ${pkg} not found (at $(pwd))"
    exit 1
  fi

  pushd $1
  echo
  echo "===> Starting package $1 build"
  if [ "$BUILD_DEB" = 1 ]; then
    echo dpkg-buildpackage -b -uc -us
  fi
  echo "===> Finished package $1 build sucessfully"
  popd
}


# ---------------------------------------------------------

# clone repository
git clone --depth 1 -b $ST2_GITREV $ST2_GITURL $GITDIR
# update code with updated sources
[ -z $GITUPDATE ] || cp -r $GITUPDATE $GITDIR

# enter root
pushd $GITDIR

# We always build st2common since other components anyway needed
# to have its wheel prebuilt beforehand
build_package st2common

# Build package loop
for pkg in $PACKAGES_TO_BUILD; do
  [ st2common = $pkg ] && continue
  build_package $pkg
done

popd

# move_packages () {
#   [ $DEBIAN -eq 1 ] && mv /code/*.deb /code/*.changes /code/*.dsc /out
# }
