#!/bin/bash
#
# Config scripts mangles /etc/st2/st2.conf to substitute needed values into
# the configuration file.
#
set -e

# --- Go!
MONGOHOST="${MONGODBHOST:-mongodb}"
RABBITMQHOST="${RABBITMQHOST:-rabbitmq}"
REDISHOST="${REDISHOST:-redis}"

CONF=/etc/st2/st2.conf
AMQP="amqp://guest:guest@$RABBITMQHOST:5672/"
MONGO=$(cat <<EHD
    [database]
    host = $MONGODBHOST
    port = 27017
EHD
)
# Don't join into one cmd with previous, otherwise it becomes
# non-interactive waiting ^D.
MONGO=$(echo "$MONGO" | sed -r 's/^\s+//')
REDIS="redis://${REDISHOST}:6379"

# Specify rabbitmq host
sed -i "/\[messaging\]/,/\[.*\]\|url/ {n; s#url.*=.*#url = $AMQP#}" $CONF
sed -i "/\[auth\]/,/\[.*\]\|enable/ {n; s#enable.*=.*#enable = False#}" $CONF

# Create database section, st2.conf ships without it
(grep "\[database\]" $CONF &>/dev/null) || echo "$MONGO" >> /etc/st2/st2.conf

# Specify redis host
sed -i "/\[coordination\]/,/\[.*\]\|url/ {n; s#url.*=.*#url = $REDIS#}" $CONF

echo  "Resulting $CONF >>>" "$(cat $CONF)"
