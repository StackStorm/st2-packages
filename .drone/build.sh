#!/bin/bash

#
#

set -e

alias ssh='ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null'

alias | grep ssh

cat /root/.ssh/id_rsa
ssh busybee@$BUILDHOST cat /test.file || true

# hmm