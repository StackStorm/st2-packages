#!/bin/bash
#
# Script installs packages on to the host system
#
set -e

PACKAGE_DIR=${PACKAGE_DIR:-packages}

# DEB / RPM
if [ -f /etc/debian_version ]; then
  # noninteractive and quiet
  INSTALLCMD="gdebi -nq"
  PKGEXT=deb
else
  INSTALLCMD=
  PKGEXT=rpm
  exit 1
fi

# Set components and ensure st2common is the first
PACKAGE_LIST="$@"
PACKAGE_LIST="st2common $(echo $PACKAGE_LIST | sed 's/st2common//')"

for name in $PACKAGE_LIST; do
  # pickup latest build
  package_path=$(ls -1t ${PACKAGE_DIR}/${name}*.${PKGEXT} | head -n1)
  fullname=$(basename $package_path)
  fullname=${fullname%%.$PKGEXT}
  echo "===> Installing package $fullname"
  $INSTALLCMD $package_path
done
