#!/bin/bash
set -e

my_dir="$(dirname "$0")"
source "$my_dir/buildenv_common.sh"

distros=($DISTROS)
DISTRO=${distros[$CIRCLE_NODE_INDEX]}

fetch_version() {
  if [ -f ../version_st2.py ]; then
    # Get st2 version based on hardcoded string in st2common
    # build takes place in `st2` repo
    python -c 'execfile("../version_st2.py"); print __version__'
  else
    # build takes place in `st2-packages` repo
    curl -sSL -o /tmp/mistral_version.py ${ST2MISTRAL_GITURL}/raw/${ST2MISTRAL_GITREV}/version_st2.py
    python -c 'execfile("/tmp/mistral_version.py"); print __version__'
  fi
}

mistral_giturl() {
  # Handle pull requests properly
  if [ -z "$CIRCLE_PR_REPONAME" ]; then
    echo "https://github.com/${CIRCLE_PROJECT_USERNAME}/${CIRCLE_PROJECT_REPONAME}"
  else
    echo "https://github.com/${CIRCLE_PR_USERNAME}/${CIRCLE_PR_REPONAME}"
  fi
}

# Mistral versioning
ST2MISTRAL_GITURL=${ST2MISTRAL_GITURL:-https://github.com/StackStorm/mistral}
ST2MISTRAL_GITREV=${ST2MISTRAL_GITREV:-$CIRCLE_BRANCH}
MISTRAL_VERSION=$(fetch_version)
if [ -n "$PACKAGECLOUD_TOKEN" ]; then
  MISTRAL_RELEASE=$(.circle/packagecloud.sh next-revision ${DISTRO} ${MISTRAL_VERSION} st2mistral)
else
  # is fork
  MISTRAL_RELEASE=1
fi

write_env ST2MISTRAL_GITURL ST2MISTRAL_GITREV MISTRAL_VERSION MISTRAL_RELEASE DISTRO TESTING

cat ~/.buildenv
