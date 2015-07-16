#!/bin/bash

# Build runner is executed on droneunit,
# the actual build process takes place on $BUILDHOST.
#
set -e
shopt -s expand_aliases
alias ssh="ssh -i /root/.ssh/busybee -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null"
alias scp="scp -i /root/.ssh/busybee -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null"

PACKAGE_LIST=${@:-${ST2_PACKAGES}}

# We exose env by providing heredoc
RUNBUILD=$(cat <<SCH
export ST2_GITURL="${ST2_GITURL:-https://github.com/StackStorm/st2}"
export ST2_GITREV="${ST2_GITREV:-master}"
echo "------------------- PACKAGE BUILD STAGE -------------------"
/bin/bash scripts/package.sh $PACKAGE_LIST
SCH
)

scp -r scripts sources busybee@$BUILDHOST: 1>/dev/null
ssh busybee@$BUILDHOST "$RUNBUILD"

# copy build artifact directory to the testing machine
scp -r busybee@$BUILDHOST:build /root/

echo "------------------- INTEGRATION TESTING STAGE -------------------"

# Install packages on the host system
/bin/bash scripts/install.sh $PACKAGE_LIST
