#!/bin/sh

# Export so the supervisord.conf has them.
export IFACE=$1
export KOTH_SSID=$2
export KOTH_IP=$3
export KOTH_FIVE=$4

exec /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
