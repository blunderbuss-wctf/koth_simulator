#!/usr/bin/env bash

# dnsmasq.sh wlan0 172.16.100.1

trap stop TERM
function stop() {
    echo "Received SIGTERM!"
    kill -TERM $PID
    rm $BASE_DIR/conf/dhcp.conf
    rm $BASE_DIR/log/dhcp.leases
}

BASE_DIR=/var/www/html/cgi-bin
INTERFACE=$1
IP=$2

mkdir $BASE_DIR/conf 2> /dev/null
mkdir $BASE_DIR/log 2> /dev/null

IFS=. read oc1 oc2 oc3 oc4 <<< $IP

LOG_FILE=$BASE_DIR/log/dnsmasq.log

cat<<EOF > $BASE_DIR/conf/dhcp.conf
interface=$INTERFACE
dhcp-range=$oc1.$oc2.$oc3.$(($oc4+1)),$oc1.$oc2.$(($oc3+100>200?200:$oc3+100)).$(($oc4+100>200?200:$oc4+100)),255.255.0.0,2M
# Gateway option number
dhcp-option=3,$IP
server=8.8.8.8
log-dhcp
log-facility=$LOG_FILE
dhcp-authoritative
# Prevent DoS attacks?
dhcp-lease-max=200
dhcp-leasefile=$BASE_DIR/log/dhcp.leases
no-resolv
no-hosts
EOF

dnsmasq -k -C $BASE_DIR/conf/dhcp.conf &
PID=$!
wait $PID
