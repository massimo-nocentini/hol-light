#!/bin/bash

SESSION_UUID=$(cat /dev/urandom | LC_CTYPE=C tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

SESSION_FIFO=/tmp/hol-light-session-$SESSION_UUID

BASE_DIR=mkfifo-sessions
OUTPUT_REDIRECTION=$BASE_DIR/hol-light-redirected-output-session-$SESSION_UUID.out
KILL_SCRIPT=$BASE_DIR/send-KILL-signal-to-ocaml-background-session-$SESSION_UUID.sh


# start the fifo queue for the asynchronuous interaction
mkfifo $SESSION_FIFO

touch $OUTPUT_REDIRECTION # to ensure that the output file exists
tail -f $SESSION_FIFO | ocaml -I `camlp5 -where` >> $OUTPUT_REDIRECTION &
OCAML_PID=$!

# make the script to send interrupts to the background process
echo "kill -SIGINT ${OCAML_PID}" > $KILL_SCRIPT
chmod +x $KILL_SCRIPT

# prepare the environment, namely begin the interaction, asynchronuously
echo "#use \"hol.ml\";;" > $SESSION_FIFO

# show the current FIFO pathname
echo "FIFO queue UUID: $SESSION_UUID"
echo "to interact with HOL send messages to the FIFO queue '$SESSION_FIFO'"
echo "to start watching eval 'tail -f $OUTPUT_REDIRECTION'"
echo "to send interrupts eval 'bash $KILL_SCRIPT'"
echo "to shutdown the FIFO queue eval 'ps' and kill the process relative to the line that starts with 'tail -f ...'"
