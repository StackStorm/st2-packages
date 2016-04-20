#!/bin/bash

# Requires: `jq` binary
# Requires: `package_cloud` gem

# Pass these ENV Variables
# PACKAGECLOUD_ORGANIZATION - Packagecloud organization (default is stackstorm)
# PACKAGECLOUD_TOKEN - act as a password for REST authentication
# IS_PRODUCTION - whether packages are for production repo (default is 0, eg. staging repo will be used)
# IS_ENTERPRISE - whether packages are for enterprise repo (default is 0, eg. community repo will be used)

# Number of latest revisions to keep for package version
# Ex: With `MAX_REVISIONS=10`, after uploading `1.3dev-20`, `1.3dev-10` will be deleted during the same run
MAX_REVISIONS=5

# Usage:
# packagecloud.sh deploy el7 /tmp/st2-packages
# IS_ENTERPRISE=1 packagecloud.sh deploy trusty /tmp/st2-packages
# packagecloud.sh next-revision trusty 0.14dev st2
# packagecloud.sh next-revision wheezy 1.3.1 st2web
function main() {
  : ${PACKAGECLOUD_ORGANIZATION:=stackstorm}
  : ${PACKAGECLOUD_TOKEN:? PACKAGECLOUD_TOKEN env is required}
  : ${IS_PRODUCTION:=0}
  : ${IS_ENTERPRISE:=0}

  case "$1" in
    deploy)
      deploy "$2" "$3"
      ;;
    next-revision)
      LATEST_REVISION=$(latest_revision "$2" "$3" "$4") || exit $?
      if [ -n "${LATEST_REVISION}" ]; then
        echo $((LATEST_REVISION+1))
      else
        echo 1
      fi
      ;;
    *)
      echo $"Usage: deploy {wheezy|jessie|trusty|el6|el7} /tmp/st2-packages"
      echo $"Usage: next-revision {wheezy|jessie|trusty|el6|el7} 0.14dev st2"
      exit 1
  esac
}

# Get PackageCloud repo name depending on environment
#
### Community:
# https://packagecloud.io/stackstorm/stable
# https://packagecloud.io/stackstorm/unstable
# https://packagecloud.io/stackstorm/staging-stable
# https://packagecloud.io/stackstorm/staging-unstable
### Enterprise:
# https://packagecloud.io/stackstorm/enterprise
# https://packagecloud.io/stackstorm/enterprise-unstable
# https://packagecloud.io/stackstorm/staging-enterprise
# https://packagecloud.io/stackstorm/staging-enterprise-unstable
function get_repo_name() {
  if [ ${IS_ENTERPRISE} -eq 0 ]; then
    if [ ${PKG_IS_UNSTABLE} -eq 0 ]; then
      PACKAGECLOUD_REPO=stable
    else
      PACKAGECLOUD_REPO=unstable
    fi

    if [ ${IS_PRODUCTION} -eq 0 ]; then
      PACKAGECLOUD_REPO="staging-${PACKAGECLOUD_REPO}"
    fi
  else
    if [ ${IS_PRODUCTION} -eq 1 ]; then
      PACKAGECLOUD_REPO=enterprise
    else
      PACKAGECLOUD_REPO=staging-enterprise
    fi

    if [ ${PKG_IS_UNSTABLE} -eq 1 ]; then
      PACKAGECLOUD_REPO="${PACKAGECLOUD_REPO}-unstable"
    fi
  fi
}

# Arguments
# $1 PKG_OS - distribution the package is built for
# $2 PKG_DIR - directory with packages to upload
function deploy() {
  : ${DEPLOY_PACKAGES:=1}
  if [ ${DEPLOY_PACKAGES} -eq 0 ]; then
    echo 'Skipping Deploy because DEPLOY_PACKAGES=0'
    exit
  fi

  PKG_OS=$1
  PKG_DIR=$2
  : ${PKG_OS:? os (first arg) is required}
  : ${PKG_DIR:? dir (second arg) is required}

  if [ ! -d "$PKG_DIR" ]; then
    echo "No directory $PKG_DIR, aborting..."
    exit 1
  fi

  for PKG_PATH in ${PKG_DIR}/*.{deb,rpm}; do
    if grep -q '*' <<< "${PKG_PATH}"; then continue; fi

    # Package name
    PKG=`basename ${PKG_PATH}`
    # deb or rpm
    PKG_TYPE=${PKG##*.}
    # Parse package metadata
    parse_${PKG_TYPE}
    # Get repo name depending on env
    get_repo_name
    # Version of the distro
    PKG_PATH_BASE=`basename $PKG_DIR`
    # Get package OS in format, suited for Packagecloud
    get_pkg_os "$PKG_OS"

    if [ -z "$PKG_NAME" ] || [ -z "$PKG_VERSION" ] || [ -z "$PKG_RELEASE" ]; then
     echo "$PKG_PATH doesn't look like package, skipping..."
     continue
    fi

    debug "PACKAGECLOUD_ORGANIZATION:  ${PACKAGECLOUD_ORGANIZATION}"
    debug "PACKAGECLOUD_REPO:          ${PACKAGECLOUD_REPO}"
    debug "PKG_PATH:                   ${PKG_PATH}"
    debug "PKG:                        ${PKG}"
    debug "PKG_NAME:                   ${PKG_NAME}"
    debug "PKG_VERSION:                ${PKG_VERSION}"
    debug "PKG_RELEASE:                ${PKG_RELEASE}"
    debug "PKG_ARCH:                   ${PKG_ARCH}"
    debug "PKG_TYPE:                   ${PKG_TYPE}"
    debug "PKG_OS_NAME:                ${PKG_OS_NAME}"
    debug "PKG_OS_VERSION:             ${PKG_OS_VERSION}"
    debug "PKG_IS_UNSTABLE:            ${PKG_IS_UNSTABLE}"

    publish
    prune_old_revision
  done
}

function debug() {
  echo "[${PACKAGECLOUD_REPO} ${PKG}] $1"
}

# Parse DEB metadata from package file name `st2api_1.2dev-20_amd64.deb`
function parse_deb() {
  # st2api
  PKG_NAME=${PKG%%_*}
  # 1.2dev
  PKG_VERSION=$(echo ${PKG} | awk -F_ '{print $2}' | awk -F- '{print $1}')
  # 20
  PKG_RELEASE=$(echo ${PKG} | awk -F_ '{print $2}' | awk -F- '{print $2}')
  # amd64
  PKG_ARCH=$(echo ${PKG##*_} | awk -F. '{print $1}')
  # stable/unstable
  PKG_IS_UNSTABLE=$(echo ${PKG_VERSION} | grep -qv 'dev'; echo $?)
}

# Parse RPM metadata from package file name `st2api-1.2dev-20.x86_64.rpm`
# https://fedoraproject.org/wiki/Packaging:NamingGuidelines
function parse_rpm() {
  # st2api
  PKG_NAME=${PKG%-*-*}
  # 1.2dev
  PKG_VERSION=$(echo ${PKG#${PKG%-*-*}-*} | awk -F- '{print $1}')
  # 20
  PKG_RELEASE=$(echo ${PKG#${PKG%-*-*}-*-} | awk -F. '{print $1}')
  # x86_64
  PKG_ARCH=$(echo ${PKG#${PKG%-*-*}-*-} | awk -F. '{print $2}')
  # stable/unstable
  PKG_IS_UNSTABLE=$(echo ${PKG_VERSION} | grep -qv 'dev'; echo $?)
}

function publish() {
  debug "Publishing ${PKG_PATH}..."
  package_cloud push ${PACKAGECLOUD_ORGANIZATION}/${PACKAGECLOUD_REPO}/${PKG_OS_NAME}/${PKG_OS_VERSION} ${PKG_PATH} || exit 1
}

function prune_old_revision() {
  if [ "$PKG_RELEASE" -gt "$MAX_REVISIONS" ]; then
    RELEASE_TO_DELETE=$((PKG_RELEASE-MAX_REVISIONS))
    PKG_TO_DELETE=${PKG/$PKG_VERSION-$PKG_RELEASE/$PKG_VERSION-$RELEASE_TO_DELETE}
    debug "Pruning obsolete revision ${PKG_VERSION}-${RELEASE_TO_DELETE} ..."
    package_cloud yank ${PACKAGECLOUD_ORGANIZATION}/${PACKAGECLOUD_REPO}/${PKG_OS_NAME}/${PKG_OS_VERSION} ${PKG_TO_DELETE}
    deleted=$?
    debug "${PKG_VERSION}-${RELEASE_TO_DELETE} deleted? y:0/N:1 (${deleted})"
  fi
}

# Arguments:
# $1 PKG_OS - distribution the package is built for
# $2 PKG_VERSION - Target package version to find latest revision for (1.1, 1.2dev)
# $3 PKG_NAME - Target package name to find latest revision for (st2, st2web)
function latest_revision() {
  PKG_OS=$1
  PKG_VERSION=$2
  PKG_NAME=$3
  : ${PKG_OS:? OS (first arg) is required}
  : ${PKG_VERSION:? version (second arg) is required}
  : ${PKG_NAME:? name (third arg) is required}

  PKG_IS_UNSTABLE=$(echo ${PKG_VERSION} | grep -qv 'dev'; echo $?)
  get_repo_name
  get_pkg_os "$PKG_OS"

  get_revision
}

# TODO: Check if CURL response code was successful
function get_versions_url() {
  curl -Ss -q https://${PACKAGECLOUD_TOKEN}:@packagecloud.io/api/v1/repos/${PACKAGECLOUD_ORGANIZATION}/${PACKAGECLOUD_REPO}/packages/${PKG_TYPE}/${PKG_OS_NAME}/${PKG_OS_VERSION}/${PKG_NAME}.json |
    jq -r .[0].versions_url
}

# TODO: Check if CURL response code was successful
function get_revision() {
  versions_url=$(get_versions_url)
  if [[ ${versions_url} == /* ]]; then
    curl -Ss -q https://${PACKAGECLOUD_TOKEN}:@packagecloud.io${versions_url} |
      jq -r "[.[] | select(.version == \"${PKG_VERSION}\") | .release | tonumber] | max"
  fi
}

# Arguments:
# $1 PKG_OS - OS codename
function get_pkg_os() {
  case "$1" in
    etch|lenny|squeeze|wheezy|jessie|stretch|buster)
      PKG_OS_NAME=debian
      PKG_OS_VERSION=$PKG_OS
      PKG_TYPE="deb"
      ;;
    warty|hoary|breezy|dapper|edgy|feisty|gutsy|hardy|intrepid|jaunty|karmic|lucid|maverick|natty|oneiric|precise|quantal|raring|saucy|trusty|utopic|vivid|wily|xenial)
      PKG_OS_NAME=ubuntu
      PKG_OS_VERSION=$PKG_OS
      PKG_TYPE="deb"
      ;;
    el5|el6|el7)
      PKG_OS_NAME=el
      PKG_OS_VERSION=${PKG_OS//[^0-9]/}
      PKG_TYPE="rpm"
      ;;
    *)
      echo "Unknown distrib '$1', aborting..."
      exit 1
  esac
}

main "$@"
