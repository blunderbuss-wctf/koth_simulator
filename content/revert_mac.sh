#!/usr/bin/env bash

printf "READY\n";

while read line; do
    ifconfig $1 down &> /dev/null
    macchanger -p $1 &> /dev/null
done < /dev/stdin
