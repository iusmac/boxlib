#!/usr/bin/env bash

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT"/../core.sh

# Initialize normal progress
progress \
    title='Example mixed progress box' \
    text='Loading...'

sleep .3

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
    sleep .3
done

# Set the overall progress to 100%
progressSet value=10

progressSet text='Finishing'
sleep .3
progressSet text='Finishing.'
sleep .3
progressSet text='Finishing..'
sleep .3
progressSet text='Finishing...'
sleep 1

# NOTE: explicitly exiting when mixed progress was used is recommended to
# properly clear the screen
progressExit
