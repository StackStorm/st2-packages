#!/bin/bash
set -e

DISTROS=(wheezy jessie trusty centos7)
TESTING=(wheezy jessie trusty)
DISTRO=${DISTROS[$CIRCLE_NODE_INDEX]}

if [ -z "$ST2_GITURL" ]; then
  # Handle pull requests properly
  if [ -z "$CIRCLE_PR_REPONAME" ]; then
    ST2_GITURL=https://github.com/${CIRCLE_PR_USERNAME}/${CIRCLE_PR_REPONAME}
  else
    ST2_GITURL=https://github.com/StackStorm/st2
  fi
  echo "export ST2_GITURL=${ST2_GITURL}" >> ~/.circlerc
fi

if [ -z "ST2_GITREV" ]; then
  ST2_GITREV=${CIRCLE_BRANCH}
  echo "export ST2_GITREV=${CIRCLE_BRANCH}" >> ~/.circlerc
fi

# Get st2 version based on hardcoded string in st2common
# build takes place in `st2` repo
if [ -f ../st2common/st2common/__init__.py ]; then
    ST2PKG_VERSION=$(python -c 'execfile("../st2common/st2common/__init__.py"); print __version__')
# build takes place in `st2-packages` repo
else
    curl -L -o /tmp/st2_version.py ${ST2_GITURL}/raw/${ST2_GITREV}/st2common/st2common/__init__.py
    ST2PKG_VERSION=$(python -c 'execfile("/tmp/st2_version.py"); print __version__')
fi

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
