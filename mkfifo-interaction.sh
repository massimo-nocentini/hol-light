#!/bin/bash

SESSION_UUID=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

SESSION_FIFO=/tmp/hol-light-session-$SESSION_UUID

BASE_DIR=./mkfifo-sessions
OUTPUT_REDIRECTION=$BASE_DIR/hol-light-redirected-output-session-$SESSION_UUID.out
KILL_SCRIPT=$BASE_DIR/send-KILL-signal-to-ocaml-background-session-$SESSION_UUID.sh

# start the fifo queue for the asynchronuous interaction
mkfifo $SESSION_FIFO

# in the `ocaml` command should be added `+I camlp5`
nohup tail -s 0.1 -f $SESSION_FIFO | ocaml > $OUTPUT_REDIRECTION & 
OCAML_PID=$!

# make the script to send interrupts to the background process
echo "kill -SIGINT ${OCAML_PID}" > $KILL_SCRIPT
chmod +x $KILL_SCRIPT

# prepare the environment, namely begin the interaction, asynchronuously
echo "#use \"hol.ml\";;" > $SESSION_FIFO

# begin watching
tail pid=$OCAML_PID -f $OUTPUT_REDIRECTION
