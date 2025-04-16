#!/usr/bin/env bash

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT"/../core.sh

function start_radiolist() {
    list \
        type='radio' \
        title='Example radio list' \
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
    text='Exited with ESC.'
elif [ $code -eq 1 ]; then # Cancel button pressed
    text='Canceled.'
elif [ -n "$result" ]; then
    text="You chose: $result"
else
    text="You didn't make any choice."
fi
text title='Radio list result' text="$text"

exit $code
