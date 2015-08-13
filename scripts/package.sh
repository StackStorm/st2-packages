#!/bin/bash
#
# Script prepares st2 repository and performs build of OS packages.
#
set -e
export WHEELDIR=/tmp/wheelhouse

if [ "x$BUILDLIST" = "x" -a "x$@" = "x" ]; then
  echo "ERROR: ./package.sh requires arguments or \$BUILDLIST to be set."
  exit 1
fi

BUILDLIST="${BUILDLIST:-${@}}"
ST2_GITURL="${ST2_GITURL:-https://github.com/StackStorm/st2}"
ST2_GITREV="${ST2_GITREV:-master}"
GITDIR=code                       # code directore
GITUPDATE="${GITUPDATE:-sources}"   # updateable sources for st2 repository
BUILD_ARTIFACT=${BUILD_ARTIFACT:-~/build}
RPMS=/root/rpmbuild/RPMS

# Take care about artifacts dir creation
[ -d $BUILD_ARTIFACT ] || mkdir -p $BUILD_ARTIFACT

# DEB / RPM
if [ -f /etc/debian_version ]; then
  BUILD_DEB=1
else
  BUILD_RPM=1
fi

# Package build function
build_package() {
  # check package directory
  if [ ! -d $1 ]; then
    echo "Package directory $1 not found (at $(pwd))"
    exit 1
  fi

  pushd $1
  echo
  echo "===> Starting package $1 build"

  # We need to extract version or use environment var if it's given
  make populate_version
  version=$(python -c "from $1 import __version__; print __version__,")
  export ST2PKG_VERSION=${ST2PKG_VERSION:-${version}}

  if [ "$BUILD_DEB" = 1 ]; then
    dpkg-buildpackage -b -uc -us
  elif [ "$BUILD_RPM" = 1 ]; then
    rpmbuild -bb rpm/$1.spec
  fi
  echo "===> Finished package $1 build sucessfully"
  popd
}


# Copy built artifact into artifacts store
copy_artifact() {
  if [ "$BUILD_DEB" = 1 ]; then
    sudo cp -v $1{*.deb,*.changes,*.dsc} $BUILD_ARTIFACT || true
  elif [ "$BUILD_RPM" = 1 ]; then
    sudo cp -v $RPMS/*/$1*.rpm $BUILD_ARTIFACT
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
BUILDLIST="st2common $(echo $BUILDLIST | sed 's/st2common//')"

if [ "$DEBUG" = "1" ]; then
  echo "DEBUG: Package build list is [${BUILDLIST}]"
fi

# Enter root and build packages in a loop
pushd $GITDIR
for pkg in $BUILDLIST; do
  build_package $pkg
  copy_artifact $pkg
done
popd

# Some debug info
if [ "$DEBUG" = 1 ]; then
  echo
  echo "DEBUG: Contents of artifacts directory ===>"
  ls -la $BUILD_ARTIFACT
fi
