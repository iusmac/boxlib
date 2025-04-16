#!/usr/bin/env bash

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT"/../core.sh

# This demo box is part of the main menu, so we'll use it's menu entry title for all boxes
config title="$1"

function start_radiolist() {
    list \
        type='radio' \
        text='Make your choice or press ESC to cancel' \
        prefix='alphanum' \
        printResult='true'

    # Create 10 choices. The 5th element will be preselected
    for nun in {1..10}; do
        local selected='false'
        if [ "$nun" -eq 5 ]; then
            selected='true'
        fi
        listEntry \
            title="Choice #$nun" \
            summary="Description of choice #$nun" \
            selected=$selected
    done

    listDraw
}

result="$(start_radiolist)"
code=$?
if [ $code -eq 255 ]; then # Escape key pressed
    text text='Exited with ESC.'
elif [ $code -eq 1 ]; then # Cancel button pressed
    text text='Canceled.'
elif [ -n "$result" ]; then
    text text="You chose: $result"
else
    text text="You didn't make any choice."
fi

exit $code
