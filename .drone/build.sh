#!/bin/bash

#
#

set -e

alias ssh='ssh -i /root/.ssh/busybee -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null'
alias | grep ssh

ssh busybee@$BUILDHOST cat /etc/hosts
