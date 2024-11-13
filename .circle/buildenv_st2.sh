#!/bin/bash

# This script is maintained in the st2 and st2-packages github repository.  Keeping them as consistent
# as possible will help avoid inconsistent behaviour in CircleCI pipeline.
set -e
set +x

my_dir="$(dirname "$0")"
source "$my_dir/buildenv_common.sh"

# DISTROS environment is set from the CircleCI pipeline.
distros=($DISTROS)
DISTRO=${distros[$CIRCLE_NODE_INDEX]}

echo "Using distro: ${DISTRO}"
echo "Using Python: $(python --version 2>&1)"

fetch_version() {
  if [ -f ../st2/st2common/st2common/__init__.py ]; then
    # Get st2 version based on hardcoded string in st2common
    # build takes place in `st2` repo
    python -c 'exec(open("../st2/st2common/st2common/__init__.py").read()); print(__version__)'
  else
    # build takes place in `st2-packages` repo
    curl -sSL -o /tmp/st2_version.py ${ST2_GITURL}/raw/${ST2_GITREV}/st2common/st2common/__init__.py
    python -c 'exec(open("/tmp/st2_version.py").read()); print(__version__)'
  fi
}

# Needs explantion???
st2_giturl() {
  # Handle pull requests properly
  if [ -z "$CIRCLE_PR_REPONAME" ]; then
    echo "https://github.com/${CIRCLE_PROJECT_USERNAME}/${CIRCLE_PROJECT_REPONAME}"
  else
    echo "https://github.com/${CIRCLE_PR_USERNAME}/${CIRCLE_PR_REPONAME}"
  fi
}

# ---
# ST2_GITURL - st2 GitHub repository (ex: https://github.com/StackStorm/st2)
# ST2_GITREV - st2 branch name (ex: master, v1.2.1). This will be used to determine correct Docker Tag: `latest`, `1.2.1`
# ST2PKG_VERSION - st2 version, will be reused in Docker image metadata (ex: 1.2dev)
# ST2PKG_RELEASE - Release number aka revision number for `st2` package, will be reused in Docker metadata (ex: 4)

ST2_GITURL=${ST2_GITURL:-https://github.com/StackStorm/st2}
ST2_GITREV=${ST2_GITREV:-master}
ST2PKG_VERSION=$(fetch_version)

# for PackageCloud
if [ -n "$PACKAGECLOUD_TOKEN" ]; then
    ST2PKG_RELEASE=$(.circle/packagecloud.sh next-revision ${DISTRO} ${ST2PKG_VERSION} st2)
else
    # is fork
    ST2PKG_RELEASE=1
fi

re="\\b$DISTRO\\b"
[[ "$NOTESTS" =~ $re ]] && TESTING=0

# Used by docker compose when run from CircleCI
ST2_CIRCLE_URL=${CIRCLE_BUILD_URL}

write_env ST2_GITURL ST2_GITREV ST2PKG_VERSION ST2PKG_RELEASE DISTRO TESTING ST2_CIRCLE_URL
cat ~/.buildenv
