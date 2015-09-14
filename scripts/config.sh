#!/bin/bash
#
# Config scripts mangles /etc/st2/st2.conf to substitute needed values into
# the configuration file.
#
set -e
set -o pipefail
. $(dirname ${BASH_SOURCE[0]})/helpers.sh


# --- Go!

debug "$0 has been invoked!"

CONF=/etc/st2/st2.conf
AMQP="amqp://guest:guest@${RABBITMQHOST}:5672/"
MONGO=$(cat <<EHD
    [database]
    host = $MONGODBHOST
    port = 27017
EHD
)
# Don't join into one cmd with previous, otherwise it becomes
# non-interactive waiting ^D.
MONGO=$(echo "$MONGO" | sed -r 's/^\s+//')

# Specify rabbitmq host
sed -i "/\[messaging\]/,/\[.*\]\|url/ {n; s#url.*=.*#url = $AMQP#}" $CONF
sed -i "/\[auth\]/,/\[.*\]\|enable/ {n; s#enable.*=.*#enable = False#}" $CONF

# Create database section, st2.conf ships without it
(grep "\[database\]" $CONF &>/dev/null) || echo "$MONGO" >> /etc/st2/st2.conf

if debug_enabled; then
  debug "Resulting $CONF >>>" "$(cat $CONF)"
fi

[ "$MISTRAL_ENABLED" = 1 ] && . /root/scripts/mistral_setup.sh
