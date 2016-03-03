#!/bin/bash

BASE_PATH="https://raw.githubusercontent.com/StackStorm/st2-packages/master/scripts/st2bootstrap"
BOOTSTRAP_FILE='st2bootstrap.sh'
ST2VER=${ST2VER:-""}

DEBTEST=`lsb_release -a 2> /dev/null | grep Distributor | awk '{print $3}'`
RHTEST=`cat /etc/redhat-release 2> /dev/null | sed -e "s~\(.*\)release.*~\1~g"`

if [[ -n "$DEBTEST" ]]; then
  TYPE="debs"
  echo "# Detected Distro is ${DEBTEST}"
  ST2BOOTSTRAP="${BASE_PATH}-deb.sh"
elif [[ -n "$RHTEST" ]]; then
  TYPE="rpms"
  echo "# Detected Distro is ${RHTEST}"
  RHMAJVER=`cat /etc/redhat-release | awk '{ print $3}' | cut -d '.' -f1`
  ST2BOOTSTRAP="${BASE_PATH}-el${RHMAJVER}.sh"
else
  echo "Unknown Operating System"
  exit 2
fi

CURLTEST=`curl --output /dev/null --silent --head --fail ${ST2BOOTSTRAP}`

if [ $? -ne 0 ]; then
    echo -e "Could not find file ${ST2BOOTSTRAP}"
    exit 2
#else
#    echo "Downloading deployment script from: ${ST2BOOTSTRAP}..."
#    curl -Ss -k -o ${BOOTSTRAP_FILE} ${ST2BOOTSTRAP}
#    chmod +x ${BOOTSTRAP_FILE}
#
#    echo "Running deployment script for St2 ${ST2VER}..."
#    bash ${BOOTSTRAP_FILE} ${ST2VER}
fi

echo "${ST2BOOTSTRAP}"
