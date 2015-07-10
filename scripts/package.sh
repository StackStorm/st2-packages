#!/bin/bash

set -e

export WHEELDIR=/tmp/wheelhouse
export DEBUG=1

PACKAGES="st2comomn st2actions st2api st2auth st2client st2reactor"
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
    dpkg-buildpackage -b -uc -us
  fi
  echo "===> Finished package $1 build sucessfully"
  popd
}


# ------------------------------- MAIN -------------------------------

# clone repository
git clone --depth 1 -b $ST2_GITREV $ST2_GITURL $GITDIR
# update code with updated sources
[ -z $GITUPDATE ] || cp -r $GITUPDATE/. $GITDIR

# We always have to pre-build st2common wheel dist and put into
# the common location since all the packages use it
pushd $GITDIR/st2common && \
  make wheelhouse && \
  python setup.py bdist_wheel -d $WHEELDIR && popd

# enter root
pushd $GITDIR

# Build package loop
for pkg in $PACKAGES_TO_BUILD; do
  build_package $pkg
done

popd

# move_packages () {
#   [ $DEBIAN -eq 1 ] && mv /code/*.deb /code/*.changes /code/*.dsc /out
# }
