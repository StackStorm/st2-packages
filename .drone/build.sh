#!/bin/bash
#
# Whole package life-cycle entrypoint.
# build -> install -> configure -> test
#

# Run ssh command on a remote host
#
ssh_cmd() {
  host="$1" && shift
  ssh "$host" "$(echo -e "${REMOTEENV}\n$@")"
}


# Preapre test host for running tests
#
testhost_setup() {
  testhost="$1"
  desc="${2:-$1}"
  echo -e "\n..... Preparing for tests on $desc"

  # Make docker links available to the remote test host
  cat /etc/hosts | sed -n '1,2d;/172.17./p' | \
    ssh $testhost "cat >> /etc/hosts"
  # Copy scripts
  scp -r scripts $testhost: 1>/dev/null

  # Get bundler gem deps
  source /etc/profile.d/rvm.sh
  DEBUG=0 bundle install
}


# Build packages on a remote node (providing customized build environment)
#
build_packages() {
  echo -e "\n..... Starting packages build on $BUILDHOST"
  # Merge upstream st2 sources (located on the build host) with updates
  # from the current repository and perform packages build.
  scp -r scripts sources $BUILDHOST: 1>/dev/null

  ssh_cmd $BUILDHOST /bin/bash scripts/package.sh
}


# Install stactorm packages on to remote test host
#
install_packages() {
  testhost="$1"
  desc="${2:-$1}"
  echo -e "\n..... Starting packages installation to $desc"

  # We can't use volumes_from in Drone, that's why perform scp
  # inside drone environment.
  [ "$COMPOSE" != "1" ] && scp -3 -r $BUILDHOST:build $testhost:

  # install st2 packages
  ssh_cmd $testhost /bin/bash scripts/install.sh

  # substitute varibles into the st2.conf configuration file
  ssh_cmd $testhost /bin/bash scripts/config.sh
}

# Start rspec on a remote test hosts
#
run_rspec() {
  testhost="$1"
  desc="${2:-$1}"
  echo -e "\n..... Executing integration tests on $desc"

  # If all packages are available, we can do full integration tests.
  l1=$(echo $BUILDLIST | sed 's/ /\n/' | sort -u)
  l2=$(echo $ST2_PACKAGES | sed 's/ /\n/' | sort -u)

  if [ "$l1" = "$l2" ]; then
    DEBUG=0 rspec spec
  else
    DEBUG=0 rspec spec/default/package*_spec.rb
  fi
}


# --- Go!
set -e

# Priority of BUILDLIST: command args > $BUILDLIST > $ST2_PACKAGES
BUILDLIST="${@:-${BUILDLIST}}"
BUILDLIST="${BUILDLIST:-${ST2_PACKAGES}}"
export BUILDLIST
export MISTRAL_DISABLED=${MISTRAL_DISABLED:-0}

# Define environment of remote services
#
BUILDHOST_IP=$(getent hosts $BUILDHOST | awk '{ print $1 }')
BUILDHOST=${BUILDHOST_IP:-$BUILDHOST}
RABBITMQHOST=${RABBITMQHOST:-rabbitmq}
MONGODBHOST=${MONGODBHOST:-mongodb}

# --- Localy needed exports
#
export RABBITMQHOST
export MONGODBHOST
export ST2_WAITFORSTART

# --- Remote environment passthrough
#
REMOTEENV=$(cat <<SCH
export DEBUG=${DEBUG:-0}
export MISTRAL_DISABLED=$MISTRAL_DISABLED
export BUILDLIST="$BUILDLIST"
export ST2_GITURL="${ST2_GITURL:-https://github.com/StackStorm/st2}"
export ST2_GITREV="${ST2_GITREV:-master}"
export BUILD_ARTIFACT=~/build
export RABBITMQHOST=$RABBITMQHOST
export MONGODBHOST=$MONGODBHOST
SCH
)

if [ "$DEBUG" = 1 ]; then
  echo "DEBUG: Remote environment passed through >>>"
  echo "$REMOTEENV"
fi

# --- SSH agent and config settings
#
if [ -z "$SSH_AUTH_SOCK" ] && [ -z "$SSH_AGENT_PID" ]; then
  eval $(ssh-agent)
fi
ssh-add /root/.ssh/busybee

cat > /root/.ssh/config <<SCH
Host *
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
SCH

# --- Start packaging life-cycle
#
if [ "$DEBUG" = 1  ]; then
  echo "DEBUG: Docker linked hosts >>>"
  cat /etc/hosts | grep '172.17'
fi

build_packages                        # - 1

for testhost in $TESTHOSTS; do
  desc="host $testhost"
  ip_addr=$(getent hosts $testhost | awk '{ print $1 }')
  export TESTHOST=${ip_addr:-$testhost}

  testhost_setup $TESTHOST "$desc"    # - 2
  install_packages $TESTHOST "$desc"  # - 3
  source /etc/profile.d/rvm.sh
  run_rspec $TESTHOST "$desc"         # - 4
done
