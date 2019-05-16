#!/usr/bin/env bash

if [ -z "$1" ]; then
    echo "usage: tmux_stats.sh <interface>"
    exit 1
fi

INTERFACE=$1
IMAGE=koth_$INTERFACE

# Check if docker instance exists for this interface
if [ -z $(docker ps -f name=$IMAGE -aq) ]; then
    echo "No $IMAGE docker image found?!?!"
    exit 1
fi

ROOT=`dirname "$(realpath $0)"`

tmux -f $ROOT/tmux.conf new-session -s "$IMAGE" -d

# Scoreboard (no scroll with watch might need to redo)
SCOREBOARD="$ROOT/scoreboard.sh $INTERFACE"
tmux send-keys "$SCOREBOARD && watch --color $SCOREBOARD" C-m

# Ap logs
tmux splitw -h -p 66
tmux send-keys "docker exec -it -t $IMAGE tail -f -n+0 /var/www/html/cgi-bin/log/hostapd.log" C-m

# Docker shell
tmux selectp -t 1
tmux splitw -v -p 20
tmux send-keys "docker exec -it $IMAGE /bin/bash" C-m

# Overall health
HEALTH="$ROOT/health.sh $INTERFACE"
tmux selectp -t 3
tmux splitw -v -p 10
tmux send-keys "$HEALTH && watch -n 1 --color $HEALTH" C-m

# Default to pane 1
tmux selectp -t 1
tmux -2 attach-session -d
