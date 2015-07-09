#!/bin/bash

#
#

set -e

alias ssh='ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null'

alias | grep ssh

echo ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null busybee@$BUILDHOST cat /etc/hosts || true
echo ssh busybee@$BUILDHOST cat /etc/hosts || true
echo ssh busybee@$BUILDHOST cat /test.file || true

sleep infinity
