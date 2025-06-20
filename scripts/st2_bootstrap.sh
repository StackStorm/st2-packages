#!/bin/bash
set +x

BASE_PATH="https://raw.githubusercontent.com/StackStorm/st2-packages"
BOOTSTRAP_FILE='st2bootstrap.sh'
ARCH=$(arch)
VERSION=''
RELEASE='stable'
REPO_TYPE=''
ST2_PKG_VERSION=''
DEV_BUILD=''
USERNAME=''
PASSWORD=''
EXTRA_OPTS=''

# Note: This variable needs to default to a branch of the latest stable release
BRANCH='v3.8'
FORCE_BRANCH=""


# pre-execution system checks.
if [[ -f "/etc/os-release" ]]; then
    source <(sed -r 's/^/OS_/g' /etc/os-release)
else
    echo "/etc/os-release is required to determine operating system."
    exit 1
fi

if [[ "$ARCH" != 'x86_64' ]]; then
    echo "Unsupported architecture.  Please use a 64-bit OS!  Aborting!"
    exit 2
fi

if [[ ! -x $(command -v curl) ]]; then
    echo >&2 "'curl' is not installed.  Aborting."
    exit 1
fi


adddate() {
    while IFS= read -r line; do
        echo "$(date +%Y%m%dT%H%M%S%z) $line"
    done
}

is_rpm() {
    [[ "rocky rhel centos fedora" =~ $OS_ID ]]
}
is_deb() {
    [[ "ubuntu debian" =~ $OS_ID ]]
}

setup_args() {
    for i in "$@"
    do
        case $i in
        -v=*|--version=*)
            VERSION="${i#*=}"
            shift
        ;;
        -s|--stable)
            RELEASE=stable
            shift
        ;;
        -u|--unstable)
            RELEASE=unstable
            shift
        ;;
        --staging)
            REPO_TYPE='staging'
            shift
        ;;
        # Used to install the packages from CircleCI build artifacts
        # Examples: 'st2/5017', 'mistral/1012', 'st2-packages/3021',
        # where first part is repository name, second is CircleCI build number.
        --dev=*)
            DEV_BUILD="${i#*=}"
            shift
        ;;
        --user=*)
            USERNAME="${i#*=}"
            shift
        ;;
        --password=*)
            PASSWORD="${i#*=}"
            shift
        ;;
        # Used to specify which branch of st2-packages repo to use. This comes handy when you
        # need to use a non-master branch of st2-package repo (e.g. when testing installer script
        # changes which are in a branch)
        --force-branch=*)
            FORCE_BRANCH="${i#*=}"
            shift
        ;;
        *)
        # unknown option
        ;;
        esac
    done

    if [[ -n "$VERSION" ]]; then
        if [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            true # noop
        elif [[ "$VERSION" =~ ^[0-9]+\.[0-9]+dev$ ]]; then
            echo "You're requesting a dev version!  Switching to unstable!"
            RELEASE='unstable'
        else
            echo "$VERSION does not match supported formats x.y.z or x.ydev"
            exit 1
        fi
    fi

    if [[ -z "$USERNAME" || -z "$PASSWORD" ]]; then
        USERNAME=${USERNAME:-st2admin}
        PASSWORD=${PASSWORD:-Ch@ngeMe}
        SLEEP_TIME=10

        echo "You can use \"--user=<CHANGEME>\" and \"--password=<CHANGEME>\" to override following default st2 credentials."
        echo "Username: ${USERNAME}"
        echo "Password: ${PASSWORD}"
        echo "Sleeping for ${SLEEP_TIME} seconds if you want to Ctrl + C now..."
        sleep ${SLEEP_TIME}
        echo "Resorting to default username and password... You have an option to change password later!"
    fi
}

setup_args $@

# Note: If either --unstable or --staging flag is provided we default branch to master
if [[ "$RELEASE" == 'unstable' ]]; then
  BRANCH="master"
fi

if [[ "$REPO_TYPE" == 'staging' ]]; then
  BRANCH="master"
fi

if [[ -n "$DEV_BUILD" ]]; then
  BRANCH="master"
fi

get_version_branch() {
    if [[ "$RELEASE" == 'stable' ]]; then
        BRANCH="v$(echo ${VERSION} | awk 'BEGIN {FS="."}; {print $1 "." $2}')"
    fi
}

if [[ -n "$VERSION" ]]; then
    get_version_branch $VERSION
    VERSION="--version=${VERSION}"
fi

if [[ -n "$RELEASE" ]]; then
    RELEASE="--${RELEASE}"
fi

if [[ "$REPO_TYPE" == 'staging' ]]; then
    REPO_TYPE="--staging"
fi

if [[ -n "$DEV_BUILD" ]]; then
    DEV_BUILD="--dev=${DEV_BUILD}"
fi

if [[ -n "${FORCE_BRANCH}" ]]; then
    BRANCH=${FORCE_BRANCH}
fi

USERNAME="--user=${USERNAME}"
PASSWORD="--password=${PASSWORD}"

echo "*** Detected distribution is ${OS_PRETTY_NAME} ***"
if is_rpm; then
    # Rocky Linux versions 8.x or 9.x
    MAJOR_VERSION=$(cut -d. -f1 <<<"$OS_VERSION_ID")
    if [[ ! "$MAJOR_VERSION" =~ ^[89] ]]; then
        echo "$OS_VERSION_ID is unsupported!"
        exit 2
    fi
    
    BOOTSTRAP_FILE="st2bootstrap-el${MAJOR_VERSION}.sh"
    ST2BOOTSTRAP="${BASE_PATH}/${BRANCH}/scripts/${BOOTSTRAP_FILE}"
elif is_deb; then
    if [[ ! "${OS_VERSION_CODENAME}" =~ focal|jammy ]]; then
        echo "Codename ${OS_VERSION_CODENAME} is unsupported!"
        exit 2
    fi
    BOOTSTRAP_FILE="st2bootstrap-deb.sh"
    ST2BOOTSTRAP="${BASE_PATH}/${BRANCH}/scripts/${BOOTSTRAP_FILE}"
else
    echo "Unsupported Operating System."
    exit 3
fi

if curl --output /dev/null --silent --head --fail "${ST2BOOTSTRAP}"; then
    echo "Downloading deployment script from: ${ST2BOOTSTRAP}..."
    # Make sure we are in a writable directory
    if [ ! -w "$(pwd)" ]; then
        echo "$(pwd) not writable, please cd to a different directory and try again."
        exit 2
    fi
    curl -sSL -k -o ${BOOTSTRAP_FILE} ${ST2BOOTSTRAP}
    chmod +x ${BOOTSTRAP_FILE}

    echo "Running deployment script for st2 ${VERSION}..."
    echo "OS specific script cmd: bash ${BOOTSTRAP_FILE} ${VERSION} ${RELEASE} ${REPO_TYPE} ${DEV_BUILD} ${USERNAME} --password=****"
    TS=$(date +%Y%m%dT%H%M%S)
    sudo mkdir -p /var/log/st2
    bash ${BOOTSTRAP_FILE} ${VERSION} ${RELEASE} ${REPO_TYPE} ${DEV_BUILD} ${USERNAME} ${PASSWORD} ${EXTRA_OPTS} 2>&1 | adddate | sudo tee "/var/log/st2/st2-install.${TS}.log"
    exit ${PIPESTATUS[0]}
else
    echo -e "Failed to download script from: ${ST2BOOTSTRAP}"
    exit 2
fi
