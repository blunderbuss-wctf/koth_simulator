#!/usr/bin/env bash

# ap.sh wlan0 WCTF_KingOfTheHill 172.16.100.1

trap stop TERM
function stop() {
    echo "Received SIGTERM!"

    kill -TERM $PID
    rm $BASE_DIR/conf/hostapd.conf

    ifconfig $INTERFACE down
    ip addr flush dev $INTERFACE

    supervisorctl start restart_koth_in_60
}

INTERFACE=$1
SSID=$2
IP=$3

BASE_DIR=/var/www/html/cgi-bin

mkdir $BASE_DIR/conf 2> /dev/null
mkdir $BASE_DIR/log 2> /dev/null

CHANNELS="1 2 3 4 5 6 7 8 9 10 11"
HW_MODE=g
`iwlist $INTERFACE freq | grep -E "Channel.*: 5\." > /dev/null`
if [[ $? -eq 0 ]]; then
    # Just use some channels from 802.11a
    CHANNELS="${CHANNELS} 36 40 44"
fi

CHANNEL=$(shuf -n 1 -e $CHANNELS)
if [[ $CHANNEL -gt 11 ]]; then
    HW_MODE=a
fi

cat<<EOF > $BASE_DIR/conf/hostapd.conf
interface=$INTERFACE
driver=nl80211
ssid=$SSID
hw_mode=$HW_MODE
ieee80211n=1
channel=$CHANNEL
logger_syslog=-1
logger_syslog_level=3
EOF

ifconfig $INTERFACE down
ip addr flush dev $INTERFACE

macchanger -A $INTERFACE

ifconfig $INTERFACE inet6 add $IP
ifconfig $INTERFACE $IP netmask 255.255.0.0
ifconfig $INTERFACE up $IP
sleep 2

echo "Starting hostapd ($INTERFACE) on channel $CHANNEL"
hostapd $BASE_DIR/conf/hostapd.conf -t &
PID=$!
wait $PID
