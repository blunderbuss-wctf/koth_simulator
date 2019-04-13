#!/bin/sh

# Export so the supervisord.conf has them.
export IFACE=$1
export KOTH_SSID=$2
export KOTH_IP=$3

sed -i "s#COMMAND#./koth_ap.sh restart $1 $2 $3 >> out.txt \&#" /var/www/html/cgi-bin/score.php

mkdir -p /var/www/html/cgi-bin/log

exec /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
