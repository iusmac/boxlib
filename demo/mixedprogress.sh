#!/usr/bin/env bash

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT"/../core.sh

# This demo box is part of the main menu, so we'll use it's menu entry title for all boxes
config title="$1"

# Adapt mixed progress update delay when recording VHS demo
if [ "${VHS:-0}" = '1' ]; then
    delay=.5
else
    delay=.3
fi

# Initialize normal progress
progress text='Loading...'

sleep $delay

# Add entries (progress will be converted to a mixed progress)
progressSet \
    entry='Task 1' state='Foobar' \
    entry='Task 2' state="$PROGRESS_SUCCEEDED_STATE" \
    entry='Task 3' state="$PROGRESS_FAILED_STATE" \
    entry='Task 4' state="$PROGRESS_PASSED_STATE" \
    entry='Task 5' state="$PROGRESS_COMPLETED_STATE" \
    entry='Task 6' state="$PROGRESS_DONE_STATE" \
    entry='Task 7' state="$PROGRESS_SKIPPED_STATE" \
    entry='Task 8' state="$PROGRESS_IN_PROGRESS_STATE"

# Assume we computed the total number
progressSet total=10

# Update the overall text and percentage to 80% while adding 2 more elements
progressSet \
    text='Starting...' \
    value='8' \
    entry='Task 9' state="-79" \
    entry='Task 10' state="-0"

sleep .5

# Increase the percentage of the Task 10 and display details in the overall text
for i in {1..10}; do
    progressSet \
        entry='Task 10' \
        state="-$((i*10))" \
        text="Work in progress... [$i/10]"
    sleep $delay
done

# 10x the total to compute more precise percentage values as Bash doesn't support floats
progressSet total=100

progressSet value=85 text='Finishing'
sleep $delay
progressSet value=90 text='Finishing.'
sleep $delay
progressSet value=95 text='Finishing..'
sleep $delay
progressSet value=100 text='Finishing...'
