#!/bin/bash

#
#

set -e

alias ssh="ssh -i /root/.ssh/busybee -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null"

ssh busybee@$BUILDHOST cat /etc/hosts || true
