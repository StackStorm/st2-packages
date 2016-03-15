#!/bin/bash

BASE_PATH="https://raw.githubusercontent.com/StackStorm/st2-packages"
BOOTSTRAP_FILE='st2bootstrap.sh'

DEBTEST=`lsb_release -a 2> /dev/null | grep Distributor | awk '{print $3}'`
RHTEST=`cat /etc/redhat-release 2> /dev/null | sed -e "s~\(.*\)release.*~\1~g"`
VERSION=''
RELEASE='stable'
REPO_TYPE='staging'
BETA=''
ST2_PKG_VERSION=''
BRANCH='master'

setup_args() {
  for i in "$@"
    do
      case $i in
          -V=*|--version=*)
          VERSION="${i#*=}"
          shift
          ;;
          -s=*|--stable)
        RELEASE=stable
          shift
          ;;
          -u=*|--unstable)
        RELEASE=unstable
          shift
          ;;
          --staging)
        REPO_TYPE='staging'
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

  echo "########################################################"
  echo "          Installing st2 $RELEASE $VERSION              "
  echo "########################################################"

  if [[ -z "$BETA"  && "$REPO_TYPE"="staging" ]]; then
    printf "\n\n"
    echo "################################################################"
    echo "### Installing from staging repos!!! USE AT YOUR OWN RISK!!! ###"
    echo "################################################################"
  fi
}

setup_args $@

get_version_branch() {
  if [[ "$RELEASE" == 'stable' ]]; then
      BRANCH="v$(echo ${VERSION} | awk 'BEGIN {FS="."}; {print $1 "." $2}')"
  fi
}

if [[ "$VERSION" != '' ]]; then
  get_version_branch $VERSION
  VERSION="--version ${VERSION}"
fi

if [[ "$RELEASE" != '' ]]; then
  RELEASE="--${RELEASE}"
fi

if [[ "$REPO_TYPE" == 'staging' ]]; then
  REPO_TYPE="--staging"
fi

if [[ -n "$DEBTEST" ]]; then
  TYPE="debs"
  echo "# Detected Distro is ${DEBTEST}"
  ST2BOOTSTRAP="${BASE_PATH}/${BRANCH}/scripts/st2bootstrap-deb.sh"
elif [[ -n "$RHTEST" ]]; then
  TYPE="rpms"
  echo "# Detected Distro is ${RHTEST}"
  RHMAJVER=`cat /etc/redhat-release | sed 's/[^0-9.]*\([0-9.]\).*/\1/'`
  ST2BOOTSTRAP="${BASE_PATH}/${BRANCH}/scripts/st2bootstrap-el${RHMAJVER}.sh"
else
  echo "Unknown Operating System"
  exit 2
fi

CURLTEST=`curl --output /dev/null --silent --head --fail ${ST2BOOTSTRAP}`

if [ $? -ne 0 ]; then
    echo -e "Could not find file ${ST2BOOTSTRAP}"
    exit 2
else
    echo "Downloading deployment script from: ${ST2BOOTSTRAP}..."
    curl -Ss -k -o ${BOOTSTRAP_FILE} ${ST2BOOTSTRAP}
    chmod +x ${BOOTSTRAP_FILE}

    echo "Running deployment script for St2 ${VERSION}..."
    bash ${BOOTSTRAP_FILE} ${VERSION} ${RELEASE} ${REPO_TYPE}
fi
