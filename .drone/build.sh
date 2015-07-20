#!/bin/bash

# Build runner is executed on droneunit,
# the actual build process takes place on $BUILDHOST.
#
set -e
shopt -s expand_aliases
alias ssh="ssh -i /root/.ssh/busybee -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null"
alias scp="scp -i /root/.ssh/busybee -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null"

export PACKAGE_DIR=/root/packages
export PACKAGE_LIST=${@:-${ST2_PACKAGES}}

# We exose env via ssh by runing heredoc command
RUNBUILD=$(cat <<SCH
export ST2_GITURL="${ST2_GITURL:-https://github.com/StackStorm/st2}"
export ST2_GITREV="${ST2_GITREV:-master}"
echo -e "\n--------------- Packages build phase ---------------"
/bin/bash scripts/package.sh $PACKAGE_LIST
SCH
)

# Merge upstream st2 sources (located on the build host) with updates
# from the current repository and perform packages build.
scp -r scripts sources busybee@$BUILDHOST: 1>/dev/null
ssh busybee@$BUILDHOST "$RUNBUILD"

# Copy build artifact directory content on to the testing machine
# (i.e. this machine where this script is run).
scp -pr busybee@$BUILDHOST:build /tmp 1>/dev/bull && \
    cp -prvT /tmp/build $PACKAGE_DIR && rm -r /tmp/build

echo -e "\n--------------- Packages installation phase ---------------"
/bin/bash scripts/install.sh $PACKAGE_LIST

source /etc/profile.d/rvm.sh
bundle install
echo -e "\n--------------- Integration tests phase ---------------"
rspec spec
