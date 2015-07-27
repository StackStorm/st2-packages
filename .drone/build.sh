#!/bin/bash

# Build runner is executed on droneunit,
# the actual build process takes place on $BUILDHOST.
#

# ssh on the build host
ssh_cmd() {
  host="$1" && shift
  ssh "$host" "$(echo -e "${REMOTEENV}\n$@")"
}

# ----- Go.
set -e
export PACKAGE_LIST="${@:-${ST2_PACKAGES}}"
export MISTRAL_DISABLED=${MISTRAL_DISABLED:-0}

# Define environment of remote services
#
BUILDHOST_IP=$(getent hosts $BUILDHOST | awk '{ print $1 }')
TESTHOST_IP=$(getent hosts $TESTHOST | awk '{ print $1 }')

BUILDHOST=${BUILDHOST_IP:-$BUILDHOST}
TESTHOST=${TESTHOST_IP:-$TESTHOST}
RABBITMQHOST=${RABBITMQHOST:-rabbitmq}
MONGODBHOST=${MONGODBHOST:-mongodb}

# Localy needed exports
#
export RABBITMQHOST
export MONGODBHOST

# Remote environment passthrough
#
REMOTEENV=$(cat <<SCH
export DEBUG=${DEBUG:-0}
export MISTRAL_DISABLED=$MISTRAL_DISABLED
export PACKAGE_LIST="$PACKAGE_LIST"
export ST2_GITURL="${ST2_GITURL:-https://github.com/StackStorm/st2}"
export ST2_GITREV="${ST2_GITREV:-master}"
export BUILD_ARTIFACT=~/build
SCH
)

# Ssh agent
if [ -z "$SSH_AUTH_SOCK" ] && [ -z "$SSH_AGENT_PID" ]; then
  eval $(ssh-agent)
fi
ssh-add /root/.ssh/busybee

cat > /root/.ssh/config <<SCH
Host *
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
SCH


if [ "$DEBUG" = "1" ]; then
  echo -e "DEBUG: Remote exports:\n${REMOTEENV}"
  echo -e "DEBUG: /etc/hosts:\n"
  cat /etc/hosts
fi

# === Build phase
# Merge upstream st2 sources (located on the build host) with updates
# from the current repository and perform packages build.
#
echo -e "\n--------------- Packages build phase ---------------"
scp -r scripts sources $BUILDHOST: 1>/dev/null
ssh_cmd $BUILDHOST /bin/bash scripts/package.sh

# === Install phase
echo -e "\n--------------- Packages install phase ---------------"

# We can't use volumes_from in Drone, that's why perform scp
# inside drone environment.
[ "$COMPOSE" != "1" ] && scp -3 -r $BUILDHOST:build $TESTHOST:

# Install st2 packages
ssh_cmd $TESTHOST /bin/bash scripts/install.sh2

# Get bundler gem deps
source /etc/profile.d/rvm.sh
bundle install

# === RSpec phase
# Make docker links available to the remote test host
cat /etc/hosts | sed -n '1,2d;/172.17.0./p' | \
  ssh $TESTHOST "cat >> /etc/hosts"
# Copy scripts
scp -r scripts $TESTHOST: 1>/dev/null

echo -e "\n--------------- Tests phase ---------------"

# If all packages are available, we can do full integration tests.
l1=$(echo $PACKAGE_LIST | sed 's/ /\n/' | sort -u)
l2=$(echo $ST2_PACKAGES | sed 's/ /\n/' | sort -u)

# Substitute varibles into the configuration file st2.conf
ssh_cmd $TESTHOST /bin/bash scripts/config.sh

if [ "$l1" = "$l2" ]; then
  rspec spec
else
  rspec spec/default/package*_spec.rb
fi
