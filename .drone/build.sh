#!/bin/bash

#
#

set -e

alias ssh='ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null'

alias | grep ssh

ssh busybee@$BUILDHOST cat /test.file || true
