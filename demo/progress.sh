#!/usr/bin/env bash

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT"/../core.sh

# Force Whiptail as renderer
[ "${1:-}" = '1' ] && config rendererName='whiptail' rendererPath='whiptail'

if [ ! ${TASK_PROGRESS_RESULT+xyz} ]; then
    export TASK_PROGRESS_RESULT=0
fi

progress \
    title='Example progress box' \
    text='Loading...' \
    width=50

sleep .5

# Update only the text in the box without updating the % value
for i in {3..1}; do
    progressSet text="Starting in: $i"
    sleep 1
done

# Assume we computed the total number
progressSet total=10

# Actually start increasing the % as we go
for ((i = TASK_PROGRESS_RESULT + 1; i <= 10; TASK_PROGRESS_RESULT = i++)); do
    progressSet \
        text="Processing elements: $i/10" \
        value="$i"

    # Simulate doing some work
    sleep .3

    # Conditionally cause the progress box to exit
    if [ "$i" -eq 5 ]; then
        progressSet text='Conditionally stopping the task...'
        sleep 2
        progressExit
        # Capture the task progress value so that we can resume from this point next time
        TASK_PROGRESS_RESULT=$i
        break
    fi
done

info text="Task result: $TASK_PROGRESS_RESULT/10\nExiting..." sleep=1.5
