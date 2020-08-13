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
ONLY_FIVE=$4
ONLY_24=$5

BASE_DIR=/var/www/html/cgi-bin

PHY=$(cat /sys/class/net/$INTERFACE/phy80211/name)
CHANNELS=$(iw phy $PHY info | sed -n '/Frequencies/,/^\s*Supported commands:\s*$/{//!p}' | grep -vE "disabled|IR" | grep -oP '\[\K[^]]+' | awk 'BEGIN {ORS=" "} {print}')

if [[ $ONLY_FIVE -eq "1" ]]; then
    CHANNELS=$(echo $CHANNELS | awk 'BEGIN {ORS=" " }; {for(i =1; i <= NF; i++) {if($i > 14) print $i;}}')
fi

if [[ $ONLY_24 -eq "1" ]]; then
    CHANNELS=$(echo $CHANNELS | awk 'BEGIN {ORS=" " }; {for(i =1; i <= NF; i++) {if($i <= 14) print $i;}}')
fi

HW_MODE=g
CHANNEL=$(shuf -n 1 -e $CHANNELS)
if [[ $CHANNEL -gt 14 ]]; then
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
