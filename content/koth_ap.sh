#!/usr/bin/env bash

##
# Attempt at creating some type of script that behaves like
# their real KOTH ap. Meaning, once executed the ap and
# dnsmasq go down for 60 seconds then are brought up again
# with a different MAC address and on a different channel.
##

# sudo ./real_fake_ap.sh start koth WCTF_KingOfTheHill 172.16.100.1

BASE_DIR=/var/www/html/cgi-bin

function usage() {
    echo "$(basename $0) <start|stop> <interface name> <ssid> <target ip>"
    echo "  interface name: the name of the interface to use."
    echo "  ssid: the name of the target ap to spoof."
    echo "  target ip: the ip address of the spoofed ap."
}

trap ctrl_c INT
function ctrl_c() {
    stop
}

function start() {
    start_dnsmasq
    start_ap
}

function stop() {
    stop_ap
    stop_dnsmasq
}

function restart() {
    sleep 1
    stop
    sleep 58
    start
}

function stop_ap() {
    kill -15 $(cat $BASE_DIR/pidfiles/${INTERFACE}_ap.pid)
    rm $BASE_DIR/pidfiles/${INTERFACE}_ap.pid
    rm $BASE_DIR/conf/${INTERFACE}_ap.conf

    ifconfig $INTERFACE down
    ip addr flush dev $INTERFACE
}

function stop_dnsmasq() {
    kill -15 $(cat $BASE_DIR/pidfiles/dhcp.pid)
    rm $BASE_DIR/pidfiles/dhcp.pid 2> /dev/null
    rm $BASE_DIR/conf/dhcp.conf
    rm $BASE_DIR/log/dhcp.leases
}

function start_dnsmasq() {
    PID_FILE=$BASE_DIR/pidfiles/dhcp.pid

    if [[ -f "$PID_FILE" ]]; then
        echo "dnsmasq instance already running on $INTERFACE. Not starting another one."
        exit 2
    fi

    mkdir $BASE_DIR/conf 2> /dev/null
    mkdir $BASE_DIR/log 2> /dev/null
    mkdir $BASE_DIR/pidfiles 2> /dev/null

    IFS=. read oc1 oc2 oc3 oc4 <<< $IP

    LOG_FILE=$BASE_DIR/log/dhcp.log

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

    dnsmasq -C $BASE_DIR/conf/dhcp.conf --pid-file=$PID_FILE
}

function start_ap() {
    REAL_AP_PID_FILE=$BASE_DIR/pidfiles/${INTERFACE}_ap.pid

    if [[ -f "$REAL_AP_PID_FILE" ]]; then
        echo "${INTERFACE} already has a running real ap. Exiting."
        exit 2
    fi

    mkdir $BASE_DIR/conf 2> /dev/null
    mkdir $BASE_DIR/log 2> /dev/null
    mkdir $BASE_DIR/pidfiles 2> /dev/null

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

    cat<<EOF > $BASE_DIR/conf/${INTERFACE}_ap.conf
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
    hostapd $BASE_DIR/conf/${INTERFACE}_ap.conf -B -P $REAL_AP_PID_FILE -t
}

COMMAND=$1
if [[ $COMMAND == "start" ]]; then

    if [ "$#" -ne 4 ]; then
        echo "Illegal number of start parameters."
        echo
        usage
        exit 1
    fi

    INTERFACE=$2
    SSID=$3
    IP=$4

    start

elif [[ $COMMAND == "stop" ]]; then

    if [ "$#" -ne 2 ]; then
        echo "Illegal number of stop parameters."
        echo
        usage
        exit 1
    fi

    INTERFACE=$2
    stop

elif [[ $COMMAND == "restart" ]]; then

    if [ "$#" -ne 4 ]; then
        echo "Illegal number of restart parameters."
        echo
        usage
        exit 1
    fi

    INTERFACE=$2
    SSID=$3
    IP=$4

    restart

else
    usage
    exit 1
fi
