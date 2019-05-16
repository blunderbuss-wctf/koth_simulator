#!/usr/bin/env bash

WHITE="\\\e[1;37m"
RED="\\\e[1;31m"
NC="\\\e[0m"
IFS=
echo -e $(docker exec koth_$1 supervisorctl status | sed -e "s/\(RUNNING\)/$WHITE\1$NC/g" -e "s/\(STOPPED\)/$RED\1$NC/g")
