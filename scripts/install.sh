#!/bin/bash

set -e

# DEB / RPM
if [ -f /etc/debian_version ]; then
  INSTALLCMD="gdebi -n"
  PKGEXT=deb
else
  INSTALLCMD=
  PKGEXT=rpm
  exit 1
fi

# Set components and ensure st2common is the first
PACKAGE_LIST="$@"
PACKAGE_LIST="st2common $(echo $PACKAGE_LIST | sed 's/st2common//')"
BUILDDIR=/root/build

for name in $PACKAGE_LIST; do
  # pickup latest build
  package_path=$(ls -1t ${BUILDDIR}/${name}*.${PKGEXT} | head -n1)
  fullname=$(basename $package_path)
  fullname=${fullname%%.$PKGEXT}
  echo "===> Installing packages $fullname"
  $INSTALLCMD $package_path
done
