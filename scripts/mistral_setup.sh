#!/bin/bash

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

DEBIAN_DEFAULT=$(cat <<EHD
    MISTRAL_LOGS="/var/log/mistral.log /var/log/mistral_wf_trace.log"
    DAEMON_ARGS="--config-file /etc/mistral/mistral.conf --log-file /var/log/mistral.log --log-config-append /etc/mistral/wf_trace_logging.conf"
EHD
)

MISTRAL=$(echo "$MISTRAL" | sed -r 's/^\s+//')
DEBIAN_DEFAULT=$(echo "$DEBIAN_DEFAULT" | sed -r 's/^\s+//')

# wf logging
mv $MISTRAL_ETCDIR/wf_trace_logging.conf.sample $MISTRAL_ETCDIR/wf_trace_logging.conf || :

# mistral config
echo "$MISTRAL" > $MISTRAL_CONF || :

# debian default
[ -f /etc/debian/default ] && echo "$DEBIAN_DEFAULT" > /etc/debian/default

( debug_enabled ) && debug "Resulting $MISTRAL_CONF >>>" "$(cat $MISTRAL_CONF)"
