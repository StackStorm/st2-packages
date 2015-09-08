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
  if [ ! -z "$BUILDHOST" ]; then
    echo -e "\n..... Starting packages build on $BUILDHOST"
    # Merge upstream st2 sources (located on the build host) with updates
    # from the current repository and perform packages build.
    scp -r scripts sources $BUILDHOST: 1>/dev/null

    ssh_cmd $BUILDHOST /bin/bash scripts/package.sh
  else
    >&2 echo -e "\n..... Packages build is skipped, BUILDHOST is not specified!"
  fi
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
  [ "$DEBUG" = 1 ] && echo "===> Invoking remote install on $testhost"
  ssh_cmd $testhost /bin/bash scripts/install.sh

  # substitute varibles into the st2.conf configuration file
  [ "$DEBUG" = 1 ] && echo "===> Invoking remote config (st2.conf) substitution on $testhost"
  ssh_cmd $testhost /bin/bash scripts/config.sh
}

# Start rspec on a remote test hosts
#
run_rspec() {
  testhost="$1"
  desc="${2:-$1}"
  echo -e "\n..... Executing integration tests on $desc"

  if ( all_packages_available ); then
    [ "$ST2_TESTMODE" = "bundle" ] && export BUILDLIST=st2bundle
    rspec spec
  else
    >&2 echo "Runing only package specific tests!"
    rspec -P '**/package_*_spec.rb' spec
  fi
}

# Exit if can not run integration tests
#
all_packages_available() {
  current=$(echo "$BUILDLIST" | sed -r 's/\s+/\n/g' | sort -u)
  available=$(echo $ST2_PACKAGES | sed -r 's/\s+/\n/g' | sort -u)
  [ "$current" = "$available" ]
}

# --- Go!
set -e

# Priority of BUILDLIST: command args > $BUILDLIST > $ST2_PACKAGES
BUILDLIST="${@:-${BUILDLIST}}"
BUILDLIST="${BUILDLIST:-${ST2_PACKAGES}}"
export BUILDLIST
export MISTRAL_DISABLED=${MISTRAL_DISABLED:-0}
export ST2_BUNDLE=$(all_packages_available && echo 1)

# Define environment of remote services
#
if [ ! -z "$BUILDHOST" ]; then
  BUILDHOST_IP=$(getent hosts $BUILDHOST | awk '{ print $1 }')
  BUILDHOST=${BUILDHOST_IP:-$BUILDHOST}
fi
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
export ST2_TESTMODE="${ST2_TESTMODE:-components}"
export ST2_BUNDLE="$ST2_BUNDLE"
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
