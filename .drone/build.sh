#!/bin/bash

# Build runner is executed on droneunit,
# the actual build process takes place on $BUILDHOST.
#
set -e
shopt -s expand_aliases
alias ssh="ssh -i /root/.ssh/busybee -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null"
alias scp="scp -i /root/.ssh/busybee -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null"

# We exose env by providing heredoc
RUNBUILD=$(cat <<SCH
export ST2_GITURL="${ST2_GITURL:-https://github.com/StackStorm/st2}"
export ST2_GITREV="${ST2_GITREV:-master}"
/bin/bash scripts/package.sh $@
SCH
)

scp -r scripts sources busybee@$BUILDHOST: &>/dev/null
ssh busybee@$BUILDHOST "$RUNBUILD"
