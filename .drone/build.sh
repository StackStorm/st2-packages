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

MISTRAL_ENABLE="${MISTRAL_ENABLE:-1}"
MISTRAL_GITURL="${MISTRAL_GITURL:-https://github.com/StackStorm/mistral}"
MISTRAL_GITREV="${MISTRAL_GITREV:-st2-0.13.1}"

RABBITMQHOST="$(hosts_resolve_ip ${RABBITMQHOST:-rabbitmq})"
MONGODBHOST="$(hosts_resolve_ip ${MONGODBHOST:-mongodb})"

# --- Go!
pipe_env DEBUG WAITFORSTART MONGODBHOST RABBITMQHOST

print_details
setup_busybee_sshenv

pipe_env GITURL=$ST2_GITURL GITREV=$ST2_GITREV GITDIR=$(mktemp -ud) \
         PRE_PACKAGE_HOOK=/root/scripts/st2pkg_version.sh

debug "Remote environment >>>" "`pipe_env`"

# Invoke st2* components build
if [ ! -z "$BUILDHOST" ]; then
  build_list="$(components_list)"
  buildhost_addr="$(hosts_resolve_ip $BUILDHOST)"

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
if [ "$MISTRAL_ENABLE" = x ]; then
  :
fi

# Integration loop, test over different platforms
msg_info "\n..... ST2 test mode is \`$ST2_TESTMODE'"

for host in $TESTHOSTS; do
  testhost_setup $host
  install_packages $host $TESTLIST
  run_rspec $host
done
