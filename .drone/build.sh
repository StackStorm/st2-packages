#!/bin/bash
#
# Whole package life-cycle entrypoint.
# build -> install -> configure -> test
#

set -e
set -o pipefail

. $(dirname ${BASH_SOURCE[0]})/pipeline.sh

# Build pipeline environment
#
DEBUG="${DEBUG:-0}"

ST2_PACKAGES="st2common st2actions st2api st2auth st2client st2reactor st2exporter st2debug"
ST2_GITURL="${ST2_GITURL:-https://github.com/StackStorm/st2}"
ST2_GITREV="${ST2_GITREV:-master}"
ST2_TESTMODE="${ST2_TESTMODE:-components}"
ST2_WAITFORSTART="${ST2_WAITFORSTART:-10}"

MISTRAL_ENABLED="${MISTRAL_ENABLED:-1}"
MISTRAL_GITURL="${MISTRAL_GITURL:-https://github.com/StackStorm/mistral}"
MISTRAL_GITREV="${MISTRAL_GITREV:-st2-0.13.1}"

RABBITMQHOST="$(hosts_resolve_ip ${RABBITMQHOST:-rabbitmq})"
MONGODBHOST="$(hosts_resolve_ip ${MONGODBHOST:-mongodb})"
POSTGRESHOST="$(hosts_resolve_ip ${POSTGRESHOST:-postgres})"

# --- Go!
pipe_env DEBUG WAITFORSTART MONGODBHOST RABBITMQHOST POSTGRESHOST MISTRAL_ENABLED

print_details
setup_busybee_sshenv

buildhost_addr="$(hosts_resolve_ip $BUILDHOST)"

# Invoke st2* components build
if [ ! -z "$BUILDHOST" ] && [ "$ST2_BUILDLIST" != " " ]; then
  build_list="$(components_list)"

  pipe_env  GITURL=$ST2_GITURL GITREV=$ST2_GITREV GITDIR=$(mktemp -ud) \
            MAKE_PRERUN=changelog \
            ST2PKG_VERSION ST2PKG_RELEASE
  debug "Remote environment >>>" "`pipe_env`"

  ssh_copy scripts $buildhost_addr:
  checkout_repo
  ssh_copy st2/* $buildhost_addr:$GITDIR
  build_packages "$build_list"
  TESTLIST="$build_list"
else
  # should be given, when run against an already built list
  TESTLIST="$(components_list)"
fi

# Test list choosing, since st2bundle conflicts with other components
if [[ "$TESTLIST" == *st2bundle* && "$ST2_TESTMODE" == "bundle" ]]; then
  TESTLIST="st2bundle"
else
  TESTLIST="$(echo $TESTLIST | sed s'/st2bundle//')"
fi

# Invoke mistral package build
if [ ! -z "$BUILDHOST" ] && [ "$MISTRAL_ENABLED" = 1 ]; then
  pipe_env  GITURL=$MISTRAL_GITURL GITREV=$MISTRAL_GITREV GITDIR=$(mktemp -ud) \
            NOCHANGEDIR=1 MAKE_PRERUN=populate_version \
            MISTRAL_VERSION MISTRAL_RELEASE
  debug "Remote environment >>>" "`pipe_env`"

  ssh_copy scripts $buildhost_addr:
  checkout_repo
  ssh_copy mistral/* $buildhost_addr:$GITDIR
  build_packages mistral
  TESTLIST="$TESTLIST mistral"
elif [ "$MISTRAL_ENABLED" = 1 ]; then
  # no build but test, can be when packages are already prebuilt...
  TESTLIST="$TESTLIST mistral"
fi

# Integration loop, test over different platforms
msg_info "\n..... ST2 test mode is \`$ST2_TESTMODE'"
debug "Remote environment >>>" "`pipe_env`"

for host in $TESTHOSTS; do
  testhost_setup $host
  install_packages $host $TESTLIST
  run_rspec $host
done
