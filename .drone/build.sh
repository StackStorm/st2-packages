#!/bin/sh

# Build runner is executed on droneunit,
# the actual build process takes place on $BUILDHOST.
#
set -e
shopt -s expand_aliases
alias ssh="ssh -i /root/.ssh/busybee -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null"
alias scp="scp -i /root/.ssh/busybee -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null"

export PACKAGE_LIST="${@:-${ST2_PACKAGES}}"

# Remote environment passthrough
#
REMOTEENV=$(cat <<SCH
export DEBUG="${DEBUG:-0}"
export PACKAGE_LIST="${PACKAGE_LIST}"
export ST2_GITURL="${ST2_GITURL:-https://github.com/StackStorm/st2}"
export ST2_GITREV="${ST2_GITREV:-master}"
export BUILD_ARTIFACT=~/build
SCH
)

[ "$DEBUG" = "1" ] && echo -e "DEBUG: Remote exports\n===>\n${REMOTEENV}"

# ssh on the build host
bh_cmd() {
  cmd=$(echo -e "${REMOTEENV}\n$@")
  ssh busybee@$BUILDHOST "${cmd}"
}

# ssh on the test host
th_cmd() {
  cmd=$(echo -e "${REMOTEENV}\n$@")
  ssh busybee@$TESTHOST "${cmd}"
}


# === Build phase
# Merge upstream st2 sources (located on the build host) with updates
# from the current repository and perform packages build.
#
echo -e "\n--------------- Packages build phase ---------------"
scp -r scripts sources busybee@$BUILDHOST: 1>/dev/null
bh_cmd /bin/bash scripts/package.sh


# === Install phase
echo -e "\n--------------- Packages install phase ---------------"

# We can't use volumes_from in Drone, that's why perform copy
if [ "$COMPOSE" != "1" ]; then
  scp -pr busybee@$BUILDHOST:build busybee@$TESTHOST 1>/dev/null
fi
scp -r scripts busybee@$TESTHOST: &>/dev/null || true
th_cmd /bin/bash scripts/install.sh


# === RSpec phase
# Get bundler gem deps
source /etc/profile.d/rvm.sh
bundle install

echo -e "\n--------------- Tests phase ---------------"
rspec spec
