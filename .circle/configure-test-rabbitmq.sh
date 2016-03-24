#!/bin/bash
set -e

sudo sh -c 'echo "[{rabbit, [{disk_free_limit, 10}, {loopback_users, []}, {tcp_listeners, [{\"0.0.0.0\", 5672}]}]}]." > /etc/rabbitmq/rabbitmq.config'
sudo service rabbitmq-server restart
