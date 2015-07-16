#!/bin/bash

set -e

export WHEELDIR=/tmp/wheelhouse
# export DEBUG

BUILD_LIST="$@"
ST2_GITURL="${ST2_GITURL:-https://github.com/StackStorm/st2}"
ST2_GITREV="${ST2_GITREV:-master}"
GITDIR=code                       # code directore
GITUPDATE=${GITUPDATE:-sources}   # updateable sources for st2 repository
ARTIFACTS_PATH=~/build

# Take care about artifacts dir creation
[ -d $ARTIFACTS_PATH ] || mkdir -p $ARTIFACTS_PATH

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


# Copy built artifact into artifacts store
copy_artifact() {
  if [ "$BUILD_DEB" = 1 ]; then
    cp -v $1{*.deb,*.changes,*.dsc} $ARTIFACTS_PATH 2>/dev/null || true
  fi 
}


# ------------------------------- MAIN -------------------------------

# clone repository
git clone --depth 1 -b $ST2_GITREV $ST2_GITURL $GITDIR

# !!! Update code with updated sources !!!
# Now this step is required, because new debian packaging code and
# new propper setuptools (setup.py) code hasn't been merged to master yet.
#
[ -z $GITUPDATE ] || cp -r $GITUPDATE/. $GITDIR

# Common is the dependency for all packages, so it's always built!
BUILD_LIST="st2common $(echo $BUILD_LIST | sed 's/st2common//')"

# Populate wheel house with st2common wheel since other packages require it!
pushd $GITDIR/st2common && make wheelhouse && \
  python setup.py bdist_wheel -d $WHEELDIR && popd

# Enter root and build packages in a loop
pushd $GITDIR
for pkg in $BUILD_LIST; do
  build_package $pkg
  copy_artifact $pkg
done
popd

# Some debug info
if [ "$DEBUG" = 1 ]; then
  echo
  echo "DEBUG: Contents of artifacts directory ===>"
  ls -1 $ARTIFACTS_PATH
fi
