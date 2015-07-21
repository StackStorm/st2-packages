#!/bin/sh
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
  INSTALLCMD=
  PKGEXT=rpm
  exit 1
fi

# Set components and ensure st2common is the first
if [ "$@" = "" -a "$PACKAGE_LIST" = "" ]; then
  echo "ERROR: ./install.sh requires arguments or \$PACKAGE_LIST to be set."
  exit 1
fi

PACKAGE_LIST=${@:-$PACKAGE_LIST}
PACKAGE_LIST="st2common $(echo $PACKAGE_LIST | sed 's/st2common//')"

if [ "$DEBUG" = "1" ]; then
  echo "DEBUG: Package installation list is [${PACKAGE_LIST}]"
  echo "DEBUG: Package directory is \`${PACKAGES_DIR}'"
fi

for name in $PACKAGE_LIST; do
  # pickup latest build
  package_path=$(ls -1t ${PACKAGES_DIR}/${name}*.${PKGEXT} | head -n1)
  [ -z $package_path ] && echo "ERROR: Couldn't find \`${PACKAGES_DIR}/${name}*'"

  fullname=$(basename $package_path)
  fullname=${fullname%%.$PKGEXT}
  echo "===> Installing package $fullname"
  $INSTALLCMD $package_path
done
