#!/bin/bash

#
set -e
shopt -s expand_aliases

alias ssh="ssh -i /root/.ssh/busybee -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null"

ssh busybee@$BUILDHOST cat /etc/hosts || true
