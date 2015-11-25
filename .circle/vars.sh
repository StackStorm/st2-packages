#!/bin/bash
set -e
set -x

DISTROS=(wheezy jessie trusty centos7)
DISTRO=${DISTROS[$CIRCLE_NODE_INDEX]}

# Package version & release hardcoded for now
# TODO: Get version from `st2common` based on (see commented block below)
ST2PKG_VERSION=1.2dev
# TODO: Get revision number based on existing Bintray packages (already uploaded)
ST2PKG_RELEASE=1

set +x
echo "export DISTROS=(${DISTROS[*]})" >> ~/.circlerc
echo "export DISTRO=${DISTRO}" >> ~/.circlerc
echo "export ST2PKG_VERSION=${ST2PKG_VERSION}" >> ~/.circlerc
echo "export ST2PKG_RELEASE=${ST2PKG_RELEASE}" >> ~/.circlerc
#    - echo ST2PKG_VERSION=$(python -c 'execfile("../st2common/st2common/__init__.py"); print __version__') >> ~/.circlerc
#    - echo "ST2PKG_RELEASE=$(scripts/bintray.sh next-revision ${DISTRO} ${ST2PKG_VERSION})" >> ~/.circlerc

set -x
cat ~/.circlerc
