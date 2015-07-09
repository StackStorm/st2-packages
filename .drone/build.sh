#!/bin/bash

#
#

set -e


ssh -i /root/.ssh/busybee -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null busybee@$BUILDHOST cat /etc/hosts || true