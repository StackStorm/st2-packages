#!/bin/bash
# TODO: With recent changes/renaming Bintray scripts needs more adjusting, when DECIDED repository naming (repos: ubuntu, debian OR repos: wheezy, trusty, jessie, etc)
# TODO: Add VCS TAG metadata for stable version (create version)

# Pass these ENV Variables
# BINTRAY_ACCOUNT - your BinTray username
# BINTRAY_API_KEY - act as a password for REST authentication

# API-related Constants
API=https://api.bintray.com
NOT_FOUND=404
SUCCESS=200
CREATED=201

# Project-related Constants
DEBIAN_DISTRIBUTION_STABLE=wheezy
DEBIAN_DISTRIBUTION_UNSTABLE=unstable
UBUNTU_DISTRIBUTION_STABLE=trusty
DEBIAN_DISTRIBUTION_UNSTABLE=unstable

# Usage:
# bintray.sh deploy debian /tmp/st2-packages
# bintray.sh deploy ubuntu /tmp/st2-packages
# bintray.sh next_revision debian 0.12dev
# bintray.sh next_revision ubuntu 1.1.2
function main() {
  : ${DEPLOY_PACKAGES:=1}
  if [ ${DEPLOY_PACKAGES} -eq 0 ]; then
    echo 'Skipping Deploy because DEPLOY_PACKAGES=0'
    exit
  fi
  : ${BINTRAY_ACCOUNT:? BINTRAY_ACCOUNT env is required}
  : ${BINTRAY_ACCOUNT:? BINTRAY_API_KEY env is required}

    case "$1" in
      deploy)
        case "$2" in
          debian)
            deploy "$2" "$3"
            ;;
          ubuntu)
            deploy "$2" "$3"
            ;;
          rpm)
            echo 'RPM is unsupported'
            ;;
          *)
            echo $"Usage: $1 {debian|ubuntu} /tmp/st2-packages"
            exit 1
        esac
        ;;
      next-revision)
        LATEST_REVISION=$(latest_revision "$2" "$3")
        if [ -n "${LATEST_REVISION}" ]; then
          echo $((LATEST_REVISION+1))
        else
          echo 1
        fi
        ;;
      *)
        echo $"Usage: deploy {debian|ubuntu} /tmp/st2-packages"
        echo $"Usage: next_revision 0.14dev"
        exit 1
    esac
}


# Arguments
# $2 BINTRAY_REPO - the targeted repo (could be rpm or deb)
# $3 PKG_DIR - directory with packages to upload
function deploy() {
  BINTRAY_REPO=$1
  PKG_DIR=$2

  : ${BINTRAY_REPO:? repo (first arg) is required}
  : ${PKG_DIR:? dir (second arg) is required}

  if [ ! -d "$PKG_DIR" ]; then
    echo "No directory $PKG_DIR, aborting..."
    exit 1
  fi

  for PKG_PATH in ${PKG_DIR}/*.deb; do

    PKG=`basename ${PKG_PATH}`
    # Parse metadata from package file name `st2api_0.14dev-20_amd64.deb`
    # st2api
    PKG_NAME=${PKG%%_*}
    # 0.14dev
    PKG_VERSION=$(echo ${PKG} | awk -F_ '{print $2}' | awk -F- '{print $1}')
    # 20
    PKG_RELEASE=$(echo ${PKG} | awk -F_ '{print $2}' | awk -F- '{print $2}')
    # amd64
    PKG_ARCH=$(echo ${PKG##*_} | awk -F. '{print $1}')
    # deb
    PKG_TYPE=${PKG##*.}
    # stable/unstable
    PKG_IS_UNSTABLE=$(echo ${PKG_VERSION} | grep -qv 'dev'; echo $?)

    if [ -z "$PKG_NAME" ] || [ -z "$PKG_VERSION" ] || [ -z "$PKG_RELEASE" ]; then
     echo "$PKG_PATH doesn't look like package, skipping..."
     continue
    fi

    echo "[${PKG}] BINTRAY_ACCOUNT:   ${BINTRAY_ACCOUNT}"
    echo "[${PKG}] BINTRAY_REPO:      ${BINTRAY_REPO}"
    echo "[${PKG}] PKG_PATH:          ${PKG_PATH}"
    echo "[${PKG}] PKG:               ${PKG}"
    echo "[${PKG}] PKG_NAME:          ${PKG_NAME}"
    echo "[${PKG}] PKG_VERSION:       ${PKG_VERSION}"
    echo "[${PKG}] PKG_RELEASE:       ${PKG_RELEASE}"
    echo "[${PKG}] PKG_ARCH:          ${PKG_ARCH}"
    echo "[${PKG}] PKG_TYPE:          ${PKG_TYPE}"
    echo "[${PKG}] PKG_IS_UNSTABLE:   ${PKG_IS_UNSTABLE}"

    init_curl
    if (! check_package_exists); then
      echo "[${PKG}] The package ${PKG_NAME} does not exit. It will be created"
      create_package
    fi

    deploy_${PKG_TYPE}
    echo "----------------------------------------------"
  done
}

function init_curl() {
  CURL="curl -u${BINTRAY_ACCOUNT}:${BINTRAY_API_KEY} -H Content-Type:application/json -H Accept:application/json"
}

function check_package_exists() {
  echo "[${PKG}] Checking if package ${PKG_NAME} exists..."
  [ $(${CURL} --write-out %{http_code} --silent --output /dev/null -X GET ${API}/packages/${BINTRAY_ACCOUNT}/${BINTRAY_REPO}/${PKG_NAME}) -eq ${SUCCESS} ]
  package_exists=$?
  echo "[${PKG}] Package ${PKG_NAME} exists? y:0/N:1 (${package_exists})"
  return ${package_exists}
}

function create_package() {
  echo "[${PKG}] Creating package ${PKG_NAME}..."
  data="{
    \"name\": \"${PKG_NAME}\",
    \"desc\": \"StackStorm event-driven automation packages\",
    \"vcs_url\": \"https://github.com/stackstorm/st2.git\",
    \"licenses\": [\"Apache-2.0\"],
    \"labels\": [\"st2\", \"devops\", \"IFTTT\", \"automation\", \"auto-remediation\", \"chatops\"],
    \"website_url\": \"https://stackstorm.com\",
    \"issue_tracker_url\": \"https://github.com/stackstorm/st2/issues\",
    \"github_repo\": \"stackstorm/st2\",
    \"github_release_notes_file\": \"CHANGELOG.rst\",
    \"public_download_numbers\": false,
    \"public_stats\": true
  }"

  ${CURL} -X POST -d "${data}" ${API}/packages/${BINTRAY_ACCOUNT}/${BINTRAY_REPO}/
  echo ""
}

function upload_content() {
  echo "[${PKG}] Uploading ${PKG_PATH}..."
  if [ ${PKG_IS_UNSTABLE} -eq 1 ]; then
    var_name="${BINTRAY_REPO^^}_DISTRIBUTION_UNSTABLE"
    DEB_DISTRIBUTION=${!var_name}
    FILE_PATH=/pool/unstable/main/${PKG_NAME:0:1}/${PKG_NAME}/${PKG}
  else
    var_name="${BINTRAY_REPO^^}_DISTRIBUTION_STABLE"
    DEB_DISTRIBUTION=${!var_name}
    FILE_PATH=/pool/stable/main/${PKG_NAME:0:1}/${PKG_NAME}/${PKG}
  fi
  [ $(${CURL} --write-out %{http_code} --silent --output /dev/null -T ${PKG_PATH} -H X-Bintray-Package:${PKG_NAME} -H X-Bintray-Version:${PKG_VERSION}-${PKG_RELEASE} -H X-Bintray-Override:1 -H X-Bintray-Debian-Distribution:${DEB_DISTRIBUTION} -H X-Bintray-Debian-Component:main -H X-Bintray-Debian-Architecture:${PKG_ARCH} ${API}/content/${BINTRAY_ACCOUNT}/${BINTRAY_REPO}/${FILE_PATH}) -eq ${CREATED} ]
  uploaded=$?
  echo "[${PKG}] DEB ${PKG_PATH} uploaded? y:0/N:1 (${uploaded})"
  return ${uploaded}
}

function deploy_deb() {
  if (upload_content); then
    echo "[${PKG}] Publishing ${PKG_PATH}..."
    ${CURL} -X POST ${API}/content/${BINTRAY_ACCOUNT}/${BINTRAY_REPO}/${PKG_NAME}/${PKG_VERSION}-${PKG_RELEASE}/publish -d "{ \"discard\": \"false\" }"
    echo ""
  else
    echo "[${PKG}] First you should upload your deb ${PKG_PATH}!"
    exit 2
  fi
}

function latest_version() {
  return $(curl -Ss -q https://dl.bintray.com/${BINTRAY_ACCOUNT}/${BINTRAY_REPO}/pool/unstable/main/s/st2api/ |
  grep 'amd64.deb' |
  sed -e "s~.*>st2api_\(.*\)-.*<.*~\1~g" |
  sort --version-sort -r |
  uniq | head -n 1)
}

# Arguments:
# $1 BINTRAY_REPO - Bintray repository to check for latest revision (debian, ubuntu)
# $2 PKG_VERSION - Target package version to find latest revision for (1.1, 1.2dev)
function latest_revision() {
  BINTRAY_REPO=$1
  PKG_VERSION=$2
  : ${BINTRAY_REPO:? repo (second arg) is required}
  : ${PKG_VERSION:? version (third arg) is required}
  PKG_IS_UNSTABLE=$(echo ${PKG_VERSION} | grep -qv 'dev'; echo $?)
  if [ ${PKG_IS_UNSTABLE} -eq 1 ]; then
    DL_DIR=unstable
  else
    DL_DIR=stable
  fi

  curl -Ss -q https://dl.bintray.com/${BINTRAY_ACCOUNT}/${BINTRAY_REPO}/pool/${DL_DIR}/main/s/st2api/ |
  grep "st2api_${PKG_VERSION}" |
  sed -e "s~.*>st2api_.*-\(.*\)_amd64.deb<.*~\1~g" |
  sort --version-sort -r |
  uniq | head -n 1
}

function deploy_rpm() {
  echo "[${PKG}] Unsupported"
  exit 0
}

main "$@"
