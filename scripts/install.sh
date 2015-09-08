#!/bin/bash
#
# Script installs packages on to the host system
#
set -e
PACKAGES_DIR=${BUILD_ARTIFACT:-build}

# DEB / RPM
if [ -f /etc/debian_version ]; then
  # noninteractive and quiet
  INSTALLCMD="sudo gdebi -nq"
  PKGEXT=deb
else
  INSTALLCMD="sudo yum -y install"
  PKGEXT=rpm
fi

if [ "x$BUILDLIST" = "x" -a "x$@" = "x" ]; then
  echo "ERROR: ./package.sh requires arguments or \$BUILDLIST to be set."
  exit 1
fi

# !!! st2common is always first since others depend on it
#
BUILDLIST="${BUILDLIST:-${@}}"
BUILDLIST="st2common $(echo $BUILDLIST | sed 's/st2common//')"

# Bundle testing is invoked and st2bundle package is available
if [ "$ST2_TESTMODE" = "bundle" ] && [ "$ST2_BUNDLE" = 1 ]; then
  BUILDLIST="st2bundle"
fi

if [ "$DEBUG" = "1" ]; then
  echo "DEBUG: Package installation list is [${BUILDLIST}]"
  echo "DEBUG: Package directory is \`${PACKAGES_DIR}'"
fi

for name in $BUILDLIST; do
  # pickup latest build
  package_path=$(ls -1t ${PACKAGES_DIR}/${name}*.${PKGEXT} | head -n1)
  [ -z $package_path ] && echo "ERROR: Couldn't find \`${PACKAGES_DIR}/${name}*'"

  fullname=$(basename $package_path)
  fullname=${fullname%%.$PKGEXT}
  echo "===> Installing package $fullname"
  $INSTALLCMD $package_path
done
