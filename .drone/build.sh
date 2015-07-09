#!/bin/bash

#
#

set -e

alias ssh='ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null'
cat /etc/hosts
pwd
echo ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null busybee@$BUILDHOST cat /etc/hosts
ssh busybee@$BUILDHOST cat /etc/hosts || true
ssh busybee@$BUILDHOST cat /test.file || true
