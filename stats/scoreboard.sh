#!/usr/bin/env bash

printf "\n%-8s %-39s%-20s\n\n" "SCORE" "TEAM" "LAST SEEN"

results=$(docker exec -it -i koth_$1 \
          awk '{
                 time=$1; $1=""; name[$0] += 1; t[$0]=time; NR==1 (max=time)
               } END {
                 for(n in name) {
                   color=(t[n]==max)?"\033[1;33m":"";
                   end=(t[n]==max)?"\033[0m":"";
                   printf "%-8s%-40s%s%-20s%s\n", name[n], n, color, strftime("%H:%M:%S UTC %D", t[n]), end;
                 }
               }' /var/www/html/cgi-bin/teams.txt | sort -s -k1,1nr)

IFS=
if [[ "$results" =~ "No such file" ]]
then
    echo "Nobody has scored yet!"
else
    echo -e "$results"
fi
