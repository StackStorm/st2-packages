#!/bin/bash
set -e

DISTROS=(wheezy jessie trusty centos7)
TESTING=(wheezy jessie trusty)
DISTRO=${DISTROS[$CIRCLE_NODE_INDEX]}

# Get st2 version based on hardcoded string in st2common
curl -L -o /tmp/st2_version.py ${ST2_GITURL}/raw/${ST2_GITREV}/st2common/st2common/__init__.py
ST2PKG_VERSION=$(python -c 'execfile("/tmp/st2_version.py"); print __version__')
# TODO: Get revision number based on existing Bintray packages (already uploaded)
ST2PKG_RELEASE=1

echo "export DISTROS=(${DISTROS[*]})" >> ~/.circlerc
echo "export TESTING=(${TESTING[*]})" >> ~/.circlerc
echo "export DISTRO=${DISTRO}" >> ~/.circlerc
echo "export ST2PKG_VERSION=${ST2PKG_VERSION}" >> ~/.circlerc
echo "export ST2PKG_RELEASE=${ST2PKG_RELEASE}" >> ~/.circlerc
#    - echo "ST2PKG_RELEASE=$(scripts/bintray.sh next-revision ${DISTRO} ${ST2PKG_VERSION})" >> ~/.circlerc

set -x
cat ~/.circlerc
