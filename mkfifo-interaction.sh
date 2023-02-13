#!/bin/bash

SESSION_UUID=$(cat /dev/urandom | LC_CTYPE=C tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

SESSION_FIFO=/tmp/hol-light-session-$SESSION_UUID

BASE_DIR=mkfifo-sessions
OUTPUT_REDIRECTION=$BASE_DIR/hol-light-redirected-output-session-$SESSION_UUID.out

PATHS="-I `camlp5 -where`"

# Loop until all parameters are used up
while [ "$1" != "" ]; do

    PATHS="$PATHS -I $1" # collect paths

    # Shift all the parameters down by one
    shift
done

echo $PATHS

# start the fifo queue for the asynchronuous interaction
mkfifo $SESSION_FIFO

touch $OUTPUT_REDIRECTION # to ensure that the output file exists
tail -f $SESSION_FIFO | ocaml $PATHS >> $OUTPUT_REDIRECTION 2> /dev/null &
OCAML_PID=$!

# prepare the environment, namely begin the interaction, asynchronuously
echo "#use \"hol.ml\";;" > $SESSION_FIFO

# write a vim script with `current-session` var declaration
echo "let fifo_queue = '${SESSION_FIFO}'" > $BASE_DIR/current-session.vim
echo "let interrupt_command = 'kill -SIGINT ${OCAML_PID}'" >> $BASE_DIR/current-session.vim

# show the current FIFO pathname
echo "FIFO queue UUID: $SESSION_UUID"
echo "to interact with HOL send messages to the FIFO queue '$SESSION_FIFO'"
echo "to start watching eval 'tail -f $OUTPUT_REDIRECTION'"
echo "to shutdown the FIFO queue eval 'ps' and kill the process relative to the line that starts with 'tail -f ...'"
