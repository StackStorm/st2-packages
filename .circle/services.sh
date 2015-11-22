#!/bin/bash
set -e

# change into script directory
cd $(dirname `readlink -f $0`)

sudo bash ./configure-postgres.sh
sudo bash ./configure-rabbitmq.sh
