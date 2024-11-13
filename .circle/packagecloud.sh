#!/bin/bash

# For script debug set -x or +x to disable
set +x

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
# packagecloud.sh deploy el8 /tmp/st2-packages
# IS_ENTERPRISE=1 packagecloud.sh deploy trusty /tmp/st2-packages
# packagecloud.sh next-revision trusty 0.14dev st2
# packagecloud.sh next-revision el8 1.3.1 st2web
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
            debug "Latest version detected: '$LATEST_REVISION'"
            if [ -n "${LATEST_REVISION}" ]; then
                echo $((LATEST_REVISION+1))
            else
                echo 1
            fi
        ;;
        *)
            echo $"Usage: deploy {focal|jammy|el8|el9} /tmp/st2-packages"
            echo $"Usage: next-revision {focal|jammy|el8|el9} 3.9dev st2"
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
    echo "$(date -Is) [${PACKAGECLOUD_REPO} ${PKG}] $1" >&2
}

# Parse DEB metadata from package file name `st2api_1.2dev-20_amd64.deb`
function parse_deb() {
    METAPKG=( $(sed -r 's@^([^_]+)_([^-]+)-([^_]+)_([^.]+)\.deb$@\1 \2 \3 \4@g' <<<$PKG) )
    if [[ 4 -ne ${#METAPKG[@]} ]]; then
        echo "Failed to extract package metadata from filename ${PKG}."
        exit 1
    fi
    # st2api
    PKG_NAME=${METAPKG[0]}
    # 1.2dev
    PKG_VERSION=${METAPKG[1]}
    # 20
    PKG_RELEASE=${METAPKG[2]}
    # amd64
    PKG_ARCH=${METAPKG[3]}
    # stable/unstable
    PKG_IS_UNSTABLE=$(grep -qv dev <<<${PKG_VERSION}; echo $?)
}

# Parse RPM metadata from package file name `st2api-1.2dev-20.x86_64.rpm`
# https://fedoraproject.org/wiki/Packaging:NamingGuidelines
function parse_rpm() {
    METAPKG=( $(sed -r 's@^([^-]+)-([^-]+)-([^.]+)\.([^.]+)\.rpm$@\1 \2 \3 \4@g' <<<$PKG) )
    if [[ 4 -ne ${#METAPKG[@]} ]]; then
        echo "Failed to extract package metadata from filename ${PKG}."
        exit 1
    fi
    # st2api
    PKG_NAME=${METAPKG[0]}
    # 1.2dev
    PKG_VERSION=${METAPKG[1]}
    # 20
    PKG_RELEASE=${METAPKG[2]}
    # x86_64
    PKG_ARCH=${METAPKG[3]}
    # stable/unstable
    PKG_IS_UNSTABLE=$(grep -qv dev <<<${PKG_VERSION}; echo $?)
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
        RET=$?
        if [[ $RET -eq 0 ]]; then
            debug "${PKG_VERSION}-${RELEASE_TO_DELETE} deleted"
        else
            debug "Unable to delete ${PKG_VERSION}-${RELEASE_TO_DELETE} (Error: ${RET})"
        fi
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
    debug "Find latest revision using ${PKG_OS} ${PKG_VERSION} ${PKG_NAME}"
    PKG_IS_UNSTABLE=$(echo ${PKG_VERSION} | grep -qv 'dev'; echo $?)
    get_repo_name
    get_pkg_os "$PKG_OS"

    get_revision
}

# TODO: Check if CURL response code was successful
function get_versions_url() {
    REPO_HOST="packagecloud.io"
    REPO_PATH="/api/v1/repos/${PACKAGECLOUD_ORGANIZATION}/${PACKAGECLOUD_REPO}/packages/${PKG_TYPE}/${PKG_OS_NAME}/${PKG_OS_VERSION}/${PKG_NAME}.json"
    REPOMETA_FILE="/tmp/${PKG_TYPE}_${PKG_OS_NAME}_${PKG_OS_VERSION}_${PKG_NAME}.json"

    curl -Ss -q "https://${PACKAGECLOUD_TOKEN}@${REPO_HOST}${REPO_PATH}" > "${REPOMETA_FILE}"
    jq -r .[0].versions_url "${REPOMETA_FILE}"
}

# TODO: Check if CURL response code was successful
function get_revision() {
    VERSION_URL="$(get_versions_url)?per_page=1000"
    VERSIONS_FILE="/tmp/${PKG_TYPE}_${PKG_OS_NAME}_${PKG_OS_VERSION}_versions.json"
    if [[ "${VERSION_URL}" == /* ]]; then
        curl -Ss -q "https://${PACKAGECLOUD_TOKEN}@packagecloud.io${VERSION_URL}" > "${VERSIONS_FILE}"
        egrep -q xtrace <<<"$SHELLOPTS" && jq . "$VERSIONS_FILE" >&2
        # A regex is used to match .version to workaround packagecloud metadata differing between rpm & deb.
        jq -r "[.[] | select(.version | test(\"^${PKG_VERSION}(-[0-9]+)?$\")) | .release | tonumber] | max" "${VERSIONS_FILE}"
    fi
}

# Arguments:
# $1 PKG_OS - OS codename
function get_pkg_os() {
    case "$1" in
        buster|bullseye|bookworm)
            PKG_OS_NAME=debian
            PKG_OS_VERSION=$PKG_OS
            PKG_TYPE="deb"
            ;;
        bionic|focal|jammy|noble)
            PKG_OS_NAME=ubuntu
            PKG_OS_VERSION=$PKG_OS
            PKG_TYPE="deb"
            ;;
        el8|el9)
            PKG_OS_NAME=el
            PKG_OS_VERSION=${PKG_OS//[^0-9]/}
            PKG_TYPE="rpm"
            ;;
        *)
            echo "Unknown distribution '$1', aborting..."
            exit 1
    esac
}

main "$@"
