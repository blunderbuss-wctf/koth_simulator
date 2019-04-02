#!/usr/bin/env bash

KOTH_SSID="WCTF_KingOfTheHill"
KOTH_IP="172.16.100.1"

MAGENTA='\e[0;35m'
RED='\e[0;31m'
GREEN='\e[0;32m'
BLUE='\e[0;34m'
NC='\e[0m'

SUBNET="192.168.7"
IP_AP="192.168.7.1"
NETMASK="/24"
ARCH=$(uname -m)

DOCKER_BUILDFILE=
DOCKER_NAME="koth"
DOCKER_IMAGE="koth_simulation"
CONF_FILE="wlan_config.txt"

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
  printf "Run it as root\n"
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
else
    echo -e "${RED}[ERROR]${NC} Only x86_64 presently supported. Exiting..."
    exit 1
fi


# Check that docker daemon is running
$(pgrep -f docker > /dev/null)
if [[ $? -ne 0 ]]
then
    echo -e "${RED}[ERROR]${NC} Docker deamon not found. Try installing then 'systemctl start docker'?"
    exit 1
fi
echo -e "[+] Docker seems to be installed and started"


function init() {
    IFACE=$1

    # Check that the requested iface is available
    if ! [ -e /sys/class/net/"$IFACE" ]
    then
        echo -e "${RED}[ERROR]${NC} The interface provided does not exist. Exiting..."
        exit 1
    fi

    # Find the physical interface for the given wireless interface
    PHY=$(cat /sys/class/net/"$IFACE"/phy80211/name)

    # Check that the given interface supports netns
    $(iw phy $PHY info | grep -q "set_wiphy_netns")
    if [[ $? -eq 1 ]]
    then
        echo -e "${RED}[ERROR]${NC} The interface $IFACE does not support set_wiphy_netns. Exiting..."
        exit 1
    fi
    echo -e "[+] Interface ${GREEN}$IFACE${NC} supports ${GREEN}set_wiphy_netns${NC}"

    # Check that the given interface is not used by the host as the default route
    if [[ $(ip r | grep default | cut -d " " -f5) == "$IFACE" ]]
    then
        echo -e "${BLUE}[INFO]${NC} The selected interface is configured as the default route, if you use it you will lose internet connectivity"
        while true; do
            read -p "Do you wish to continue? [y/n]" yn
            case $yn in
                [Yy]* ) break;;
                [Nn]* ) exit;;
                * ) echo "Please answer yes or no.";;
            esac
        done
    fi

    # Number of phy interfaces
    NUM_PHYS=$(iw dev | grep -c phy)
    echo -e "${BLUE}[INFO]${NC} Number of physical wireless interfaces connected: ${GREEN}$NUM_PHYS${NC}"

    # See if this adapter supports 5GHz
    SUPPORT="2.4"
    `iwlist $IFACE freq | grep -E "Channel.*: 5\." > /dev/null`
    if [[ $? -eq 0 ]]; then
        SUPPORT="${SUPPORT} and 5"
    fi
    echo -e "${BLUE}[INFO]${NC} Selected interface supports ${GREEN}${SUPPORT}${NC} bands"

    # Checking if the docker image has been already pulled
    IMG_CHECK=$(docker images -q $DOCKER_IMAGE)
    if [ "$IMG_CHECK" != "" ]
    then
        echo -e "${BLUE}[INFO]${NC} Docker image ${GREEN}$DOCKER_IMAGE${NC} found"
    else
	if [[ -e /sys/module/overlay/parameters/metacopy ]]
	then
            echo N > /sys/module/overlay/parameters/metacopy
	fi
        echo -e "${BLUE}[INFO]${NC} Docker image ${RED}$DOCKER_IMAGE${NC} not found"
        echo -e "[+] Building the image ${GREEN}$DOCKER_IMAGE${NC}..."
        docker build -q --rm -t $DOCKER_IMAGE -f $DOCKER_BUILDFILE .
        if [[ $? -ne 0 ]]
        then
            echo -e "${RED}[ERROR]${NC} Error building ${RED}$DOCKER_IMAGE${NC}. Exiting..."
            exit 1
        fi
    fi

    echo -e "${BLUE}[INFO]${NC} Bringing ${IFACE} up"
    ip link set $IFACE up

    # Check if a wlan config file exists, else take wlan parameters by default
    if [ -e "$CONF_FILE" ]
    then
        echo -e "${BLUE}[INFO]${NC} Found WLAN config file"
        # Parse the wlan config file
        IFS="="
        while read -r name value; do
            case $name in
                ''|\#* ) continue;;
                "KOTH_SSID" )
                    KOTH_SSID=${value//\"/}
                    echo -e "${BLUE}"[INFO]"${NC}" SSID: "${MAGENTA}""$KOTH_SSID""${NC}";;
                "KOTH_IP" )
                    KOTH_IP=${value//\"/}
                    echo -e "${BLUE}"[INFO]"${NC}" SSID: "${MAGENTA}""$KOTH_IP""${NC}";;
                * )
                    echo Parameter "$name" in "$CONF_FILE" not recognized
            esac
        done < "$CONF_FILE"
    else
        echo -e "${BLUE}[INFO]${NC} WLAN config file not found. Setting default WLAN parameters"
        echo -e "${BLUE}"[INFO]"${NC}" SSID: "${MAGENTA}""$KOTH_SSID""${NC}"
        echo -e "${BLUE}"[INFO]"${NC}" IP: "${MAGENTA}""$KOTH_IP""${NC}"
    fi
}

function service_start() {
    IFACE="$1"

    DOCKER_IMAGE=koth_simulation
    echo -e "[+] Starting the docker container with name ${GREEN}$DOCKER_NAME${NC}"
    docker run -dt --name $DOCKER_NAME --net=bridge --cap-add=NET_ADMIN --cap-add=NET_RAW $DOCKER_IMAGE > /dev/null 2>&1
    pid=$(docker inspect -f '{{.State.Pid}}' $DOCKER_NAME)

    # Assign phy wireless interface to the container
    mkdir -p /var/run/netns
    ln -s /proc/"$pid"/ns/net /var/run/netns/"$pid"
    iw phy "$PHY" set netns "$pid"

    # Assign an IP to the wifi interface
    echo -e "[+] Configuring ${GREEN}$IFACE${NC} with IP address ${GREEN}$IP_AP${NC}"
    ip netns exec "$pid" ip addr flush dev "$IFACE"
    ip netns exec "$pid" ip link set "$IFACE" up
    ip netns exec "$pid" ip addr add "$IP_AP$NETMASK" dev "$IFACE"

    # iptables rules for NAT
    echo "[+] Adding natting rule to iptables (container)"
    ip netns exec "$pid" iptables -t nat -A POSTROUTING -s $SUBNET.0$NETMASK ! -d $SUBNET.0$NETMASK -j MASQUERADE

    # Enable IP forwarding
    echo "[+] Enabling IP forwarding (container)"
    ip netns exec "$pid" echo 1 > /proc/sys/net/ipv4/ip_forward

    # Need to feed the score.php with the correct configs
    docker exec -i "$DOCKER_NAME" bash <<EOF
       sed -i "s#COMMAND#./koth_ap.sh restart $IFACE $KOTH_SSID $KOTH_IP >> out.txt \&#" /var/www/html/cgi-bin/score.php
EOF

    echo -e "[+] Starting ${GREEN}WCTF KOTH Simulation${NC} in the docker container \
${GREEN}$DOCKER_NAME${NC} on interface ${GREEN}$IFACE${NC}"
    docker exec "$DOCKER_NAME" /var/www/html/cgi-bin/koth_ap.sh start $IFACE $KOTH_SSID $KOTH_IP
}

function service_stop() {
    IFACE="$1"

    echo -e "[+] Stopping ${GREEN}$DOCKER_NAME${NC}"
    docker stop $DOCKER_NAME > /dev/null 2>&1

    echo -e "[+] Removing ${GREEN}$DOCKER_NAME${NC}"
    docker rm $DOCKER_NAME > /dev/null 2>&1

    echo -e "[+] Removing IP address in ${GREEN}$IFACE${NC}"
    ip addr del "$IP_AP$NETMASK" dev "$IFACE" > /dev/null 2>&1

    # Clean up dangling symlinks
    find -L /var/run/netns -type l -delete 2>/dev/null
}

if [ "$1" == "start" ]
then
    if [[ -z "$2" ]]
    then
        echo -e "${RED}[ERROR]${NC} No interface provided. Exiting..."
        exit 1
    fi
    IFACE=${2}
    service_stop "$IFACE"
    init "$IFACE"
    service_start "$IFACE"
elif [ "$1" == "stop" ]
then
    if [[ -z "$2" ]]
    then
        echo -e "${RED}[ERROR]${NC} No interface provided. Exiting..."
        exit 1
    fi
    IFACE=${2}
    service_stop "$IFACE"
else
    show_usage
fi
