#!/bin/bash

# Requires: jq

# Pass these ENV Variables
# PACKAGECLOUD_ORGANIZATION - Packagecloud organization (default is stackstorm)
# PACKAGECLOUD_TOKEN - act as a password for REST authentication

# Usage:
# packagecloud.sh deploy wheezy_staging /tmp/st2-packages
# packagecloud.sh deploy trusty /tmp/st2-packages
# packagecloud.sh next-revision trusty 0.12dev st2api
# packagecloud.sh next-revision wheezy 1.1.2 st2web
function main() {
  : ${PACKAGECLOUD_ORGANIZATION:=stackstorm}

  case "$1" in
    deploy)
      deploy "$2" "$3" "$4"
      ;;
    next-revision)
      LATEST_REVISION=$(latest_revision "$2" "$3" "$4" "$5")
      if [ -n "${LATEST_REVISION}" ]; then
        echo $((LATEST_REVISION+1))
      else
        echo 1
      fi
      ;;
    last-revision)
      echo $(latest_revision "$2" "$3" "$4" "$5")
      ;;
    *)
      echo $"Usage: deploy {st2|st2_staging} {trusty|whezzy|el7} /tmp/st2-packages"
      echo $"Usage: next-revision {st2|st2_staging} {trusty|whezzy|el7} 0.14dev st2api"
      echo $"Usage: last-revision {st2|st2_staging} {trusty|whezzy|el7} 0.14dev st2api"
      exit 1
  esac
}

# Arguments
# $2 PACKAGECLOUD_REPO - the targeted repo (could be rpm or deb)
# $3 PKG_OS - distribution the package is built for
# $4 PKG_DIR - directory with packages to upload
function deploy() {
  # : ${BINTRAY_ACCOUNT:? BINTRAY_ACCOUNT env is required}
  : ${PACKAGECLOUD_TOKEN:? PACKAGECLOUD_TOKEN env is required}
  : ${DEPLOY_PACKAGES:=1}
  if [ ${DEPLOY_PACKAGES} -eq 0 ]; then
    echo 'Skipping Deploy because DEPLOY_PACKAGES=0'
    exit
  fi
  PACKAGECLOUD_REPO=$1
  PKG_OS=$2
  PKG_DIR=$3

  : ${PACKAGECLOUD_REPO:? repo (first arg) is required}
  : ${PKG_OS:? os (second arg) is required}
  : ${PKG_DIR:? dir (third arg) is required}

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
    # Version of the distro
    PKG_PATH_BASE=`basename $PKG_DIR`

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
  package_cloud push ${PACKAGECLOUD_ORGANIZATION}/${PACKAGECLOUD_REPO}/${PKG_OS_NAME}/${PKG_OS_VERSION} ${PKG_PATH}
  echo ""
}

# Arguments:
# $2 PACKAGECLOUD_REPO - the targeted repo (could be rpm or deb)
# $3 PKG_OS - distribution the package is built for
# $4 PKG_VERSION - Target package version to find latest revision for (1.1, 1.2dev)
# $5 PKG_NAME - Target package name to find latest revision for (st2api, st2web)
function latest_revision() {
  PACKAGECLOUD_REPO=$1
  PKG_OS=$2
  PKG_VERSION=$3
  PKG_NAME=$4
  : ${PACKAGECLOUD_REPO:? repo (second arg) is required}
  : ${PACKAGECLOUD_REPO:? repo (third arg) is required}
  : ${PKG_VERSION:? version (fourth arg) is required}
  : ${PKG_NAME:? name (fifth arg) is required}
  PKG_IS_UNSTABLE=$(echo ${PKG_VERSION} | grep -qv 'dev'; echo $?)
  if [ ${PKG_IS_UNSTABLE} -eq 1 ]; then
    DL_DIR=unstable
  else
    DL_DIR=stable
  fi

  get_pkg_os "$PKG_OS"

  get_revision
}

function get_versions_url() {
  curl -Ss -q https://${PACKAGECLOUD_TOKEN}:@packagecloud.io/api/v1/repos/${PACKAGECLOUD_ORGANIZATION}/${PACKAGECLOUD_REPO}/packages/${PKG_TYPE}/${PKG_OS_NAME}/${PKG_OS_VERSION}/${PKG_NAME}.json |
  jq -r .[0].versions_url
}

function get_revision() {
  curl -Ss -q https://${PACKAGECLOUD_TOKEN}:@packagecloud.io$(get_versions_url) |
  jq -r "[.[] | select(.version == \"${PKG_VERSION}\") | .release] | max"
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
      echo Unknown distrib $PKG_PATH_BASE. Skipping...
      continue
  esac
}

main "$@"
