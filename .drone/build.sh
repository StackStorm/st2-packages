#!/bin/bash

#
set -e
shopt -s expand_aliases
alias ssh="ssh -i /root/.ssh/busybee -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null"
alias scp="scp -i /root/.ssh/busybee -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null"

# We exose env by providing heredoc
RUNBUILD=$(cat <<SCH
export ST2_GITURL="${ST2_GITURL:-https://github.com/StackStorm/st2}"
export ST2_GITREV="${ST2_GITREV:-master}"
/bin/bash scripts/package.sh
SCH
)


scp -r scripts busybee@$BUILDHOST
ssh -t busybee@$BUILDHOST "$RUNBUILD"
