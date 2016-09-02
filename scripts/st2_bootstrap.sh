#!/bin/bash

BASE_PATH="https://raw.githubusercontent.com/StackStorm/st2-packages"
BOOTSTRAP_FILE='st2bootstrap.sh'

ARCH=`arch`
DEBTEST=`lsb_release -a 2> /dev/null | grep Distributor | awk '{print $3}'`
RHTEST=`cat /etc/redhat-release 2> /dev/null | sed -e "s~\(.*\)release.*~\1~g"`
VERSION=''
RELEASE='stable'
REPO_TYPE=''
ST2_PKG_VERSION=''
USERNAME=''
PASSWORD=''

# Note: This variable needs to default to a branch of the latest stable release
BRANCH='v2.0'

setup_args() {
  for i in "$@"
    do
      case $i in
          -v|--version=*)
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
          --user=*)
          USERNAME="${i#*=}"
          shift
          ;;
          --password=*)
          PASSWORD="${i#*=}"
          shift
          ;;
          *)
          # unknown option
          ;;
      esac
    done

  if [[ "$VERSION" != '' ]]; then
    if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] && [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+dev$ ]]; then
      echo "$VERSION does not match supported formats x.y.z or x.ydev"
      exit 1
    fi

    if [[ "$VERSION" =~ ^[0-9]+\.[0-9]+dev$ ]]; then
     echo "You're requesting a dev version! Switching to unstable!"
     RELEASE='unstable'
    fi
  fi

  if [[ "$USERNAME" = '' || "$PASSWORD" = '' ]]; then
    USERNAME=${USERNAME:-st2admin}
    PASSWORD=${PASSWORD:-Ch@ngeMe}
    echo "You can use \"--user=<CHANGEME>\" and \"--password=<CHANGEME>\" to override following default st2 credentials."
    SLEEP_TIME=10
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

get_version_branch() {
  if [[ "$RELEASE" == 'stable' ]]; then
      BRANCH="v$(echo ${VERSION} | awk 'BEGIN {FS="."}; {print $1 "." $2}')"
  fi
}

if [[ "$VERSION" != '' ]]; then
  get_version_branch $VERSION
  VERSION="--version=${VERSION}"
fi

if [[ "$RELEASE" != '' ]]; then
  RELEASE="--${RELEASE}"
fi

if [[ "$REPO_TYPE" == 'staging' ]]; then
  REPO_TYPE="--staging"
fi

USERNAME="--user=${USERNAME}"
PASSWORD="--password=${PASSWORD}"

if [[ "$ARCH" != 'x86_64' ]]; then
  echo "Unsupported architecture. Please use a 64-bit OS! Aborting!"
  exit 2
fi

if [[ -n "$RHTEST" ]]; then
  TYPE="rpms"
  echo "*** Detected Distro is ${RHTEST} ***"
  RHMAJVER=`cat /etc/redhat-release | sed 's/[^0-9.]*\([0-9.]\).*/\1/'`
  echo "*** Detected distro version ${RHMAJVER} ***"
  if [[ "$RHMAJVER" != '6' && "$RHMAJVER" != '7' ]]; then
    echo "Unsupported distro version $RHMAJVER! Aborting!"
    exit 2
  fi
  ST2BOOTSTRAP="${BASE_PATH}/${BRANCH}/scripts/st2bootstrap-el${RHMAJVER}.sh"
  BOOTSTRAP_FILE="st2bootstrap-el${RHMAJVER}.sh"
elif [[ -n "$DEBTEST" ]]; then
  TYPE="debs"
  echo "*** Detected Distro is ${DEBTEST} ***"
  SUBTYPE=`lsb_release -a 2>&1 | grep Codename | grep -v "LSB" | awk '{print $2}'`
  echo "*** Detected flavor ${SUBTYPE} ***"
  if [[ "$SUBTYPE" != 'trusty' ]]; then
    echo "Unsupported ubuntu flavor ${SUBTYPE}. Please use 14.04 (trusty) as base system!"
    exit 2
  fi
  ST2BOOTSTRAP="${BASE_PATH}/${BRANCH}/scripts/st2bootstrap-deb.sh"
  BOOTSTRAP_FILE="st2bootstrap-deb.sh"
else
  echo "Unknown Operating System"
  exit 2
fi

hash curl 2>/dev/null || { echo >&2 "'curl' is not installed. Aborting."; exit 1; }

CURLTEST=`curl --output /dev/null --silent --head --fail ${ST2BOOTSTRAP}`
if [ $? -ne 0 ]; then
    echo -e "Could not find file ${ST2BOOTSTRAP}"
    exit 2
else
    echo "Downloading deployment script from: ${ST2BOOTSTRAP}..."
    curl -Ss -k -o ${BOOTSTRAP_FILE} ${ST2BOOTSTRAP}
    chmod +x ${BOOTSTRAP_FILE}

    echo "Running deployment script for st2 ${VERSION}..."
    echo "OS specific script cmd: bash ${BOOTSTRAP_FILE} ${VERSION} ${RELEASE} ${REPO_TYPE} ${USERNAME} ${PASSWORD}"
    bash ${BOOTSTRAP_FILE} ${VERSION} ${RELEASE} ${REPO_TYPE} ${USERNAME} ${PASSWORD}
fi
