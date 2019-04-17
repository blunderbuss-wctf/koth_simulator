# WCTF KOTH Game

The Wireless Village hosts a King of the Hill (KOTH) competition which forces teams to submit their team name to the WCTF_KingOfTheHill AP as many times as possible. With each successful submission the AP becomes locked for 60 seconds at which time no team can submit their team name and score. Once the 60 seconds have expired the AP becomes active again at which time all teams compete again to score.

Upon connecting to the WCTF_KingOfTheHill AP teams need to obtain a DHCP lease, then navigate to 172.16.100.1 (this IP has been known to change with each con) and submit their team name. Submitting the team name logs the team's success! Weighted points are awarded to the teams with successful submissions at the conclusion of the WCTF; as long as there is a minimum of 30 submissions the points are awared. Oh, and this challenge does not sleep when they close the doors for the night.

The code in this repo is just a very poor attempt at a simulation of this KOTH game. We have no knowledge of how the real KOTH implementation works or how it is built. This project is simply a means to test our own custom defense and offense scripts.

# Installing

Docker is being used here to help avoid conflicts with the local running system (webserver, network, ...). The install instructions are fairly generic which should allow the simulation to run on most hosts.

Arch Linux x86_64
```
pacman -S docker
systemctl start docker
```

Ubuntu 16.04 x86_64
```
apt-get install docker
systemctl start docker
```

Ubuntu 18.04 x86_64
```
sudo apt-get remove docker docker-engine docker.io containerd runc

sudo apt-get update
sudo apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io
```

Kali on RPi 3 aarch64
```
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
echo 'deb https://download.docker.com/linux/debian stretch stable' > /etc/apt/sources.list.d/docker.list
apt-get update 
apt-get remove docker docker-engine docker.io
apt-get install docker-ce
```

# Requirements

Aside from only presently supporting a few hosts, the selected nic to use for the simulation must support <b>set_wiphy_netns</b>. This is because of the network namespacing in use. The run.sh script does an explicit check of this condition. You can also check the device itself with:
```
iw phy phy<#> info | grep set_wiphy_netns 
```

# Running

The <i>run.sh</i> script is all that is needed to start and stop the simulation. To start the simulation:
```
#./run.sh start wlan0

  _  _____ _____ _  _     _   ___ 
 | |/ / _ \_   _| || |   /_\ | _ 
 |   < (_)  | | | __ |  / _ \|  _/
 |_|\_\___/ |_| |_||_| /_/ \_\_| 

Do you want to play a game...

[+] Docker seems to be installed and started
[+] Stopping koth_wlan0
[+] Removing koth_wlan0
[+] Removing IP address in wlan0
[+] Interface wlan0 supports set_wiphy_netns
.
.
.
.
```

To stop the simulation:
```
# ./run.sh stop wlan0

  _  _____ _____ _  _     _   ___ 
 | |/ / _ \_   _| || |   /_\ | _ 
 |   < (_)  | | | __ |  / _ \|  _/
 |_|\_\___/ |_| |_||_| /_/ \_\_| 

Do you want to play a game...

[+] Docker seems to be installed and started
[+] Stopping koth_wlan0
[+] Removing koth_wlan0
[+] Removing IP address in wlan0
```

# Display Team Score
To run a continuous display of the team scores just run the following outside the running docker instance.
```
> watch "docker exec -it -t koth_wlan0 cat /var/www/html/cgi-bin/teams.txt | sort | uniq -c"

      2 blunderbuss
      1 others
```

# Handy Docker Commands
* docker exec -it -t koth /bin/bash
* docker ps -a
* docker images
* docker rmi <image id>
* docker stop <container id>
* docker rm <container id>
