#!/bin/bash
set -e

distros=($DISTROS)
DISTRO=${distros[$CIRCLE_NODE_INDEX]}


# Discover st2 giturl, eg. the codebase we work with
# In case of forked PR - it will use user's `st2` giturl
get_st2_giturl() {
  # Handle pull requests properly
  if [ -z "$CIRCLE_PR_REPONAME" ]; then
    echo "https://github.com/${CIRCLE_PROJECT_USERNAME}/${CIRCLE_PROJECT_REPONAME}"
  else
    echo "https://github.com/${CIRCLE_PR_USERNAME}/${CIRCLE_PR_REPONAME}"
  fi
}

# Discover the st2 branch we work with
get_st2_gitrev() {
  if echo "${CIRCLE_BRANCH}" | grep -q '^v[0-9]\+\.[0-9]\+$'; then
    echo "${CIRCLE_BRANCH}"
  else
    echo "master"
  fi
}

# Discover st2 version based on st2common `__init__` file
get_st2_version() {
  if [ -f ../st2common/st2common/__init__.py ]; then
    # Get st2 version based on hardcoded string in st2common
    # build takes place in `st2` repo
    python -c 'execfile("../st2common/st2common/__init__.py"); print __version__'
  else
    # build takes place in `st2-packages` repo
    curl -sSL -o /tmp/st2_version.py ${ST2_GITURL}/raw/${ST2_GITREV}/st2common/st2common/__init__.py
    python -c 'execfile("/tmp/st2_version.py"); print __version__'
  fi
}

# Write export lines into ~/.buildenv and also source it in ~/.circlerc
write_env() {
  for e in $*; do
    eval "value=\$$e"
    [ -z "$value" ] || echo "export $e=$value" >> ~/.buildenv
  done
  echo ". ~/.buildenv" >> ~/.circlerc
}

# ---
# ST2_GITURL - st2 GitHub repository (ex: https://github.com/StackStorm/st2)
# ST2_GITREV - st2 branch name (ex: master, v1.2.1). This will be used to determine correct Docker Tag: `latest`, `1.2.1`
# ST2PKG_VERSION - st2 version, will be reused in Docker image metadata (ex: 1.2dev)
# ST2PKG_RELEASE - Release number aka revision number for `st2` package, will be reused in Docker metadata (ex: 4)
# ST2_WAITFORSTART - Delay between st2 start and service checks

ST2_GITURL=${ST2_GITURL:-$(get_st2_giturl)}
ST2_GITREV=${ST2_GITREV:-$(get_st2_gitrev)}
ST2PKG_VERSION=$(get_st2_version)
# for Bintray
#ST2PKG_RELEASE=$(.circle/bintray.sh next-revision ${DISTRO}_staging ${ST2PKG_VERSION} st2)
# for PackageCloud
if [ -z "$CIRCLE_PR_REPONAME" ]; then
  ST2PKG_RELEASE=$(.circle/packagecloud.sh next-revision ${DISTRO} ${ST2PKG_VERSION} st2)
else
  # is fork
  ST2PKG_RELEASE=1
fi


# Mistral versioning
# Nasty hack until CI for Mistral is done: https://github.com/StackStorm/st2-packages/issues/82
ST2MISTRAL_GITURL=${ST2MISTRAL_GITURL:-https://github.com/StackStorm/mistral}
ST2MISTRAL_GITREV=${ST2MISTRAL_GITREV:-st2-1.3.2}
MISTRAL_VERSION=${MISTRAL_VERSION:-1.3.2}
if [ -z "$CIRCLE_PR_REPONAME" ]; then
  MISTRAL_RELEASE=$(.circle/packagecloud.sh next-revision ${DISTRO} ${MISTRAL_VERSION} st2mistral)
else
  # is fork
  MISTRAL_RELEASE=1
fi


re="\\b$DISTRO\\b"
[[ "$NOTESTS" =~ $re ]] && TESTING=0

write_env ST2_GITURL ST2_GITREV ST2PKG_VERSION ST2PKG_RELEASE ST2_WAITFORSTART DISTRO TESTING ST2MISTRAL_GITURL ST2MISTRAL_GITREV MISTRAL_VERSION MISTRAL_RELEASE

cat ~/.buildenv
