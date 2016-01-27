#!/bin/bash

platform() {
  [ -f /etc/debian_version ] && { echo 'deb'; return 0; }
  echo 'rpm'
}

RABBITMQHOST="${RABBITMQHOST:-rabbitmq}"
POSTGRESHOST="${POSTGRESHOST:-postgres}"

MISTRAL_CONFSRC=/root/mistral-conf
MISTRAL_ETCDIR=/etc/mistral
MISTRAL_CONF=$MISTRAL_ETCDIR/mistral.conf

MISTRAL=$(cat <<EHD
    [DEFAULT]
    transport_url = rabbit://guest:guest@$RABBITMQHOST:5672
    [database]
    connection = postgresql://mistral:StackStorm@$POSTGRESHOST/mistral
    max_pool_size = 50
    [pecan]
    auth_enable = false
EHD
)

MISTRAL=$(echo "$MISTRAL" | sed -r 's/^\s+//')

# mistral config
echo "$MISTRAL" > $MISTRAL_CONF || :

# Populate tables of the mistral database can be invoked ONLY
# AFTER creating the mistral databasue, so make sure:
# 0) you create database mistral identified for mistral:StackStorm
# 1) mistral should be started
# 2) mistral-db-manage populate should be invoked

echo "Resulting $MISTRAL_CONF >>>" "$(cat $MISTRAL_CONF)"
