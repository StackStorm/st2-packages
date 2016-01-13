#!/bin/bash
# TODO: Add VCS TAG metadata for stable version (create version)

# Pass these ENV Variables
# BINTRAY_ACCOUNT - your BinTray username
# BINTRAY_API_KEY - act as a password for REST authentication
# BINTRAY_ORGANIZATION - Bintray organization (optional, defaults to `stackstorm`)

# API-related Constants
API=https://api.bintray.com
NOT_FOUND=404
SUCCESS=200
CREATED=201

# Usage:
# bintray.sh deploy wheezy_staging /tmp/st2-packages
# bintray.sh deploy trusty /tmp/st2-packages
# bintray.sh next-revision trusty 0.12dev st2api
# bintray.sh next-revision wheezy 1.1.2 st2web
function main() {
  : ${BINTRAY_ORGANIZATION:=stackstorm}

    case "$1" in
      deploy)
        deploy "$2" "$3"
        ;;
      next-revision)
        LATEST_REVISION=$(latest_revision "$2" "$3" "$4")
        if [ -n "${LATEST_REVISION}" ]; then
          echo $((LATEST_REVISION+1))
        else
          echo 1
        fi
        ;;
      *)
        echo $"Usage: deploy {wheezy_staging|jessie_staging|trusty_staging} /tmp/st2-packages"
        echo $"Usage: next-revision {wheezy_staging|jessie_staging|trusty_staging} 0.14dev st2api"
        exit 1
    esac
}

# Arguments
# $2 BINTRAY_REPO - the targeted repo (could be rpm or deb)
# $3 PKG_DIR - directory with packages to upload
function deploy() {
  : ${BINTRAY_ACCOUNT:? BINTRAY_ACCOUNT env is required}
  : ${BINTRAY_API_KEY:? BINTRAY_API_KEY env is required}
  : ${DEPLOY_PACKAGES:=1}
  if [ ${DEPLOY_PACKAGES} -eq 0 ]; then
    echo 'Skipping Deploy because DEPLOY_PACKAGES=0'
    exit
  fi
  BINTRAY_REPO=$1
  PKG_DIR=$2

  : ${BINTRAY_REPO:? repo (first arg) is required}
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

    if [ -z "$PKG_NAME" ] || [ -z "$PKG_VERSION" ] || [ -z "$PKG_RELEASE" ]; then
     echo "$PKG_PATH doesn't look like package, skipping..."
     continue
    fi

    debug "BINTRAY_ACCOUNT:       ${BINTRAY_ACCOUNT}"
    debug "BINTRAY_ORGANIZATION:  ${BINTRAY_ORGANIZATION}"
    debug "BINTRAY_REPO:          ${BINTRAY_REPO}"
    debug "PKG_PATH:              ${PKG_PATH}"
    debug "PKG:                   ${PKG}"
    debug "PKG_NAME:              ${PKG_NAME}"
    debug "PKG_VERSION:           ${PKG_VERSION}"
    debug "PKG_RELEASE:           ${PKG_RELEASE}"
    debug "PKG_ARCH:              ${PKG_ARCH}"
    debug "PKG_TYPE:              ${PKG_TYPE}"
    debug "PKG_IS_UNSTABLE:       ${PKG_IS_UNSTABLE}"

    init_curl
    if (! check_package_exists); then
      debug "The package ${PKG_NAME} does not exist. It will be created"
      create_package
    fi

    publish
  done
}

function init_curl() {
  CURL="curl -u${BINTRAY_ACCOUNT}:${BINTRAY_API_KEY} -H Content-Type:application/json -H Accept:application/json"
}

function debug() {
  echo "[${BINTRAY_REPO} ${PKG}] $1"
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

function check_package_exists() {
  debug "Checking if package ${PKG_NAME} exists..."
  [ $(${CURL} --write-out %{http_code} --silent --output /dev/null -X GET ${API}/packages/${BINTRAY_ORGANIZATION}/${BINTRAY_REPO}/${PKG_NAME}) -eq ${SUCCESS} ]
  package_exists=$?
  debug "Package ${PKG_NAME} exists? y:0/N:1 (${package_exists})"
  return ${package_exists}
}

function create_package() {
  debug "Creating package ${PKG_NAME}..."
  data="{
    \"name\": \"${PKG_NAME}\",
    \"desc\": \"Packages for StackStorm event-driven automation platform\",
    \"vcs_url\": \"https://github.com/stackstorm/st2.git\",
    \"licenses\": [\"Apache-2.0\"],
    \"labels\": [\"st2\", \"StackStorm\", \"DevOps\", \"automation\", \"auto-remediation\", \"chatops\"],
    \"website_url\": \"https://stackstorm.com\",
    \"issue_tracker_url\": \"https://github.com/stackstorm/st2/issues\",
    \"github_repo\": \"stackstorm/st2\",
    \"github_release_notes_file\": \"CHANGELOG.rst\",
    \"public_download_numbers\": false,
    \"public_stats\": true
  }"

  ${CURL} -X POST -d "${data}" ${API}/packages/${BINTRAY_ORGANIZATION}/${BINTRAY_REPO}/
  echo ""
}

function publish() {
  if (upload_${PKG_TYPE}); then
    debug "Publishing ${PKG_PATH}..."
    ${CURL} -X POST ${API}/content/${BINTRAY_ORGANIZATION}/${BINTRAY_REPO}/${PKG_NAME}/${PKG_VERSION}-${PKG_RELEASE}/publish -d "{ \"discard\": \"false\" }"
    echo ""
  else
    debug "First you should upload your file ${PKG_PATH}!"
    exit 2
  fi
}

function upload_deb() {
  debug "Uploading ${PKG_PATH}..."
  if [ ${PKG_IS_UNSTABLE} -eq 1 ]; then
    DEBIAN_DISTRIBUTION=unstable
    FILE_PATH=/pool/unstable/main/${PKG_NAME:0:1}/${PKG_NAME}/${PKG}
  else
    DEBIAN_DISTRIBUTION=stable
    FILE_PATH=/pool/stable/main/${PKG_NAME:0:1}/${PKG_NAME}/${PKG}
  fi
  [ $(${CURL} --write-out %{http_code} --silent --output /dev/null -T ${PKG_PATH} -H X-Bintray-Package:${PKG_NAME} -H X-Bintray-Version:${PKG_VERSION}-${PKG_RELEASE} -H X-Bintray-Override:1 -H X-Bintray-Debian-Distribution:${DEBIAN_DISTRIBUTION} -H X-Bintray-Debian-Component:main -H X-Bintray-Debian-Architecture:${PKG_ARCH} ${API}/content/${BINTRAY_ORGANIZATION}/${BINTRAY_REPO}/${FILE_PATH}) -eq ${CREATED} ]
  uploaded=$?
  debug "DEB ${PKG_PATH} uploaded? y:0/N:1 (${uploaded})"
  return ${uploaded}
}

function upload_rpm() {
  debug "Uploading ${PKG_PATH}..."
  if [ ${PKG_IS_UNSTABLE} -eq 1 ]; then
    FILE_PATH=/unstable/${PKG}
  else
    FILE_PATH=/stable/${PKG}
  fi
  [ $(${CURL} --write-out %{http_code} --silent --output /dev/null -T ${PKG_PATH} -H X-Bintray-Package:${PKG_NAME} -H X-Bintray-Version:${PKG_VERSION}-${PKG_RELEASE} -H X-Bintray-Override:1 ${API}/content/${BINTRAY_ORGANIZATION}/${BINTRAY_REPO}/${FILE_PATH}) -eq ${CREATED} ]
  uploaded=$?
  debug "DEB ${PKG_PATH} uploaded? y:0/N:1 (${uploaded})"
  return ${uploaded}
}

# Arguments:
# $1 BINTRAY_REPO - Bintray repository to check for latest revision (debian, ubuntu)
# $2 PKG_VERSION - Target package version to find latest revision for (1.1, 1.2dev)
# $3 PKG_NAME - Target package name to find latest revision for (st2api, st2web)
function latest_revision() {
  BINTRAY_REPO=$1
  PKG_VERSION=$2
  PKG_NAME=$3
  : ${BINTRAY_REPO:? repo (second arg) is required}
  : ${PKG_VERSION:? version (third arg) is required}
  : ${PKG_NAME:? name (fourth arg) is required}
  PKG_IS_UNSTABLE=$(echo ${PKG_VERSION} | grep -qv 'dev'; echo $?)
  if [ ${PKG_IS_UNSTABLE} -eq 1 ]; then
    DL_DIR=unstable
  else
    DL_DIR=stable
  fi

  case "$BINTRAY_REPO" in
    *'el6'*)
      REPO_TYPE='rpm'
    ;;
    *'el7'*)
      REPO_TYPE='rpm'
    ;;
    *)
      REPO_TYPE='deb'
    ;;
  esac

  ${REPO_TYPE}_revision
}

deb_revision() {
  curl -Ss -q https://dl.bintray.com/${BINTRAY_ORGANIZATION}/${BINTRAY_REPO}/pool/${DL_DIR}/main/s/${PKG_NAME}/ |
  grep -v '\.deb\.' |
  grep "${PKG_NAME}_${PKG_VERSION}" |
  sed -e "s~.*>${PKG_NAME}_.*-\(.*\)_amd64.deb<.*~\1~g" |
  sort --version-sort -r |
  uniq | head -n 1
}

rpm_revision() {
  curl -Ss -q https://dl.bintray.com/${BINTRAY_ORGANIZATION}/${BINTRAY_REPO}/${DL_DIR}/ |
  grep -v '\.rpm\.' |
  grep "${PKG_NAME}-${PKG_VERSION}" |
  sed -e "s~.*>${PKG_NAME}-.*-\(.*\).x86_64.rpm<.*~\1~g" |
  sort --version-sort -r |
  uniq | head -n 1
}

main "$@"
