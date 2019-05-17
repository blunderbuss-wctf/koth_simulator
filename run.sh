#!/usr/bin/env bash

KOTH_SSID="WCTF_KingOfTheHill"
KOTH_IP="172.16.100.1"
KOTH_SCOREBOARD="<not set>"
KOTH_FIVEGHZ="0"

MAGENTA='\e[0;35m'
RED='\e[0;31m'
GREEN='\e[0;32m'
BLUE='\e[0;34m'
NC='\e[0m'

IFACE=
SUBNET="192.168.7"
IP_AP="192.168.7.1"
NETMASK="/24"
ARCH=$(uname -m)

DOCKER_BUILDFILE=
DOCKER_NAME=
DOCKER_IMAGE="koth_simulation"
CONF_FILE="wlan_config.txt"
TARGET_SCORE=/var/www/html/cgi-bin/teams.txt

clear

cat <<EOF
  _  _____ _____ _  _     _   ___
 | |/ / _ \_   _| || |   /_\ | _
 |   < (_)  | | | __ |  / _ \|  _/
 |_|\_\___/ |_| |_||_| /_/ \_\_|

Do you want to play a game...

EOF


function show_usage () {
    echo "================================"
    echo "| Start or stop the KOTH game. |"
    echo "================================"
    echo
    echo "Usage:"
    echo "$0 <start|stop> [interface]"
    echo ""
    exit 1
}


# Must run as root
if [ x"$(command -v id 2> /dev/null)" != "x" ]
then
  USERID="$(id -u 2> /dev/null)"
fi

if [ "x${USERID}" = "x" ] && [ "x${UID}" != "x" ]
then
  USERID=${UID}
fi

if [ x${USERID} != "x" ] && [ x${USERID} != "x0" ]
then
  echo -e "Run it as root"
  exit 1
fi


# Argument check
if [ "$#" -eq 0 ] || [ "$#" -gt 2 ] || [ "$1" == "help" ]
then
    show_usage
fi


# Arch check
if [[ $ARCH == "x86_64" ]]
then
    DOCKER_BUILDFILE=build/Dockerfile_x86_64
elif [[ $ARCH == "aarch64" ]]
then
    DOCKER_BUILDFILE=build/Dockerfile_aarch64
elif [[ $ARCH == "armv7l" ]]
then
    DOCKER_BUILDFILE=build/Dockerfile_armv7l
else
    echo -e "${RED}[ERROR]${NC} $ARCH not presently supported. Exiting!"
    exit 1
fi


# Check that docker is installed/running
$(docker info > /dev/null)
if [[ $? -ne 0 ]]
then
    echo -e "${RED}[ERROR]${NC} Docker deamon not found. Try installing then 'systemctl start docker'?"
    exit 1
fi
echo -e "[+] Docker seems to be installed and started"


function init() {
    # Check that the requested iface is available
    if ! [ -e /sys/class/net/$IFACE ]
    then
        echo -e "${RED}[ERROR]${NC} The interface provided does not exist. Exiting!"
        exit 1
    fi

    # Find the physical interface for the given wireless interface
    local phy=$(cat /sys/class/net/$IFACE/phy80211/name)

    # Check that the given interface supports AP interface mode
    $(iw phy $phy info | grep -E "\* AP\s*$")
    if [[ $? -eq 1 ]]
    then
        echo -e "${RED}[ERROR]${NC} $IFACE does not support AP interface mode. Exiting!"
        exit 1
    fi
    echo -e "[+] Interface ${GREEN}$IFACE${NC} supports ${GREEN}AP interface mode${NC}"

    # Check that the given interface supports netns
    $(iw phy $phy info | grep -q "set_wiphy_netns")
    if [[ $? -eq 1 ]]
    then
        echo -e "${RED}[ERROR]${NC} The interface $IFACE does not support set_wiphy_netns. Exiting!"
        exit 1
    fi
    echo -e "[+] Interface ${GREEN}$IFACE${NC} supports ${GREEN}set_wiphy_netns${NC}"

    # Show channel support (explicitly avoid DFS channels)
    local channels=$(iw phy $phy info | sed -n '/Frequencies/,/^\s*Supported commands:\s*$/{//!p}' | grep -vE "disabled|IR" | grep -oP '\[\K[^]]+' | awk 'BEGIN {ORS=" "} {print}')
    echo -e "[+] Interface supports channels ${GREEN}$channels${NC}"

    # Check that the given interface is not used by the host as the default route
    if [[ $(ip r | grep default | cut -d " " -f5) == "$IFACE" ]]
    then
        echo -e "${BLUE}[INFO]${NC} Selected interface configured as default route, if you use it you will lose internet connectivity"
        while true; do
            read -p "Do you wish to continue? [y/n]" yn
            case $yn in
                [Yy]* ) break;;
                [Nn]* ) exit;;
                * ) echo "Please answer yes or no.";;
            esac
        done
    fi

    # Check if a wlan config file exists, else take wlan parameters by default
    if [ -e "$CONF_FILE" ]
    then
        echo -e "${BLUE}[INFO]${NC} Found WLAN config file: $CONF_FILE"
        # Parse the wlan config file
        IFS="="
        while read -r name value; do
            case $name in
                ''|\#* ) continue;;
                "KOTH_SSID" )
                    KOTH_SSID=${value//\"/};;
                "KOTH_IP" )
                    KOTH_IP=${value//\"/};;
                "KOTH_SCOREBOARD" )
                    KOTH_SCOREBOARD=${value//\"/};;
                "KOTH_FIVEGHZ" )
                    KOTH_FIVEGHZ=${value//\"/};;
                * )
                    echo -e "Parameter $name in $CONF_FILE not recognized"
            esac
        done < "$CONF_FILE"
    fi

    if [[ $KOTH_FIVEGHZ -eq "1" ]]; then
        channels=$(echo $channels | awk 'BEGIN {ORS=" " }; {for(i =1; i <= NF; i++) {if($i > 14) print $i;}}')
    fi

    echo -e "${BLUE}[INFO]${NC} WLAN parameters:"
    echo -e "${BLUE}[INFO]${NC} SSID: ${MAGENTA}$KOTH_SSID${NC}"
    echo -e "${BLUE}[INFO]${NC} IP: ${MAGENTA}$KOTH_IP${NC}"
    echo -e "${BLUE}[INFO]${NC} SCOREBOARD: ${MAGENTA}$KOTH_SCOREBOARD${NC}"
    echo -e "${BLUE}[INFO]${NC} 5GHz ONLY: ${MAGENTA}$KOTH_FIVEGHZ${NC}"
    echo -e "${BLUE}[INFO]${NC} USING CHANNELS: ${MAGENTA}$channels${NC}"

    if [[ -z "$channels" ]]; then
        echo -e "${RED}[ERROR]${NC} No channels selected for use. Did you mistakenly set KOTH_FIVEGHZ?"
        exit 1
    fi

    # Avoid cross-device link error with building?
    if [[ -e /sys/module/overlay/parameters/metacopy ]]
    then
        echo N > /sys/module/overlay/parameters/metacopy
    fi

    # Build the damn container
    echo -e "[+] Building the image ${GREEN}$DOCKER_IMAGE${NC}...(this might take some time)"
    docker build -q --rm -t $DOCKER_IMAGE -f $DOCKER_BUILDFILE .
    if [[ $? -ne 0 ]]
    then
        echo -e "${RED}[ERROR]${NC} Error building ${RED}$DOCKER_IMAGE${NC}. Exiting!"
        exit 1
    fi
}

function start() {
    echo -e "[+] Bringing up ${GREEN}$IFACE${NC}"
    ip link set $IFACE up

    echo -e "[+] Starting the docker container with name ${GREEN}$DOCKER_NAME${NC}"

    if [[ $KOTH_SCOREBOARD != "<not set>" ]]
    then
        docker run -dt --name $DOCKER_NAME --net=bridge --cap-add=NET_ADMIN --cap-add=NET_RAW -v ${KOTH_SCOREBOARD}:${TARGET_SCORE} $DOCKER_IMAGE $IFACE $KOTH_SSID $KOTH_IP $KOTH_FIVEGHZ
    else
        docker run -dt --name $DOCKER_NAME --net=bridge --cap-add=NET_ADMIN --cap-add=NET_RAW $DOCKER_IMAGE $IFACE $KOTH_SSID $KOTH_IP $KOTH_FIVEGHZ
    fi

    if [[ $? -ne 0 ]]
    then
        echo -e "${RED}[ERROR]${NC} Error running ${GREEN}$DOCKER_NAME${NC}. Exiting!"
        exit 1
    fi

    local pid=$(docker inspect -f '{{.State.Pid}}' $DOCKER_NAME)
    local phy=$(cat /sys/class/net/$IFACE/phy80211/name)

    # Assign phy wireless interface to the container
    mkdir -p /var/run/netns
    ln -s /proc/$pid/ns/net /var/run/netns/$pid
    iw phy $phy set netns $pid

    # Assign an IP to the wifi interface
    echo -e "[+] Configuring ${GREEN}$IFACE${NC} with IP address ${GREEN}$IP_AP${NC}"
    ip netns exec $pid ip addr flush dev $IFACE
    ip netns exec $pid ip link set $IFACE up
    ip netns exec $pid ip addr add $IP_AP$NETMASK dev $IFACE

    # iptables rules for NAT
    echo "[+] Adding natting rule to iptables (container)"
    ip netns exec $pid iptables -t nat -A POSTROUTING -s $SUBNET.0$NETMASK ! -d $SUBNET.0$NETMASK -j MASQUERADE

    # Enable IP forwarding
    echo "[+] Enabling IP forwarding (container)"
    ip netns exec $pid echo 1 > /proc/sys/net/ipv4/ip_forward

    echo -e "[!] Started ${GREEN}WCTF KOTH Simulation${NC} in container ${GREEN}$DOCKER_NAME${NC}"
}

function stop() {
    local pid=$(docker inspect -f '{{.State.Pid}}' $DOCKER_NAME 2> /dev/null)

    echo -e "[+] Stopping ${GREEN}$DOCKER_NAME${NC}"
    docker stop $DOCKER_NAME > /dev/null 2>&1

    echo -e "[+] Removing ${GREEN}$DOCKER_NAME${NC}"
    docker rm $DOCKER_NAME > /dev/null 2>&1

    echo -e "[+] Removing IP address in ${GREEN}$IFACE${NC}"
    ip addr del $IP_AP$NETMASK dev $IFACE > /dev/null 2>&1

    # Clean up dangling symlinks
    find -L /var/run/netns/$pid -type l -delete 2>/dev/null
}

if [ "$1" == "start" ]
then
    if [[ -z "$2" ]]
    then
        echo -e "${RED}[ERROR]${NC} No interface provided. Exiting!"
        exit 1
    fi
    IFACE=$2
    DOCKER_NAME="koth_$IFACE"
    stop
    init
    start
elif [ "$1" == "stop" ]
then
    if [[ -z "$2" ]]
    then
        echo -e "${RED}[ERROR]${NC} No interface provided. Exiting!"
        exit 1
    fi
    IFACE=$2
    DOCKER_NAME="koth_$IFACE"
    stop
    echo -e "[!] Removed ${GREEN}$DOCKER_NAME${NC}"
else
    show_usage
fi
