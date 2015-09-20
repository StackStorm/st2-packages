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

CREATE_MISTRAL_ROLE=$(cat <<EHD
import psycopg2
conn = psycopg2.connect("user=postgres host=$POSTGRESHOST password=")
cur = conn.cursor()
cur.execute("CREATE ROLE mistral WITH CREATEDB LOGIN ENCRYPTED PASSWORD 'StackStorm';")
conn.commit()
cur.close()
conn.close()
EHD
)


DEFAULT_ENV=$(cat <<EHD
    DAEMON_ARGS="--config-file /etc/mistral/mistral.conf --log-file /var/log/mistral/mistral.log --log-config-append /etc/mistral/wf_trace_logging.conf"
EHD
)

MISTRAL=$(echo "$MISTRAL" | sed -r 's/^\s+//')
DEFAULT_ENV=$(echo "$DEFAULT_ENV" | sed -r 's/^\s+//')

# mistral config
echo "$MISTRAL" > $MISTRAL_CONF || :

# set up default env
if [ "$(platform)" = debian ]; then
  echo "$DEFAULT_ENV" > /etc/default/mistral
else
  echo "$DEFAULT_ENV" > /etc/sysconfig/mistral
fi

# We need to populate mistral so that mistral on drone
# can connect using mistral:StackStorm.
if [ "$COMPOSE" != 1 ]; then
  echo "$CREATE_MISTRAL_ROLE" | /usr/share/python/mistral/bin/python -
fi

if debug_enabled; then
  debug "Resulting $MISTRAL_CONF >>>" "$(cat $MISTRAL_CONF)"
fi
