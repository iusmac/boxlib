#!/usr/bin/env bash

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT"/../core.sh

# This demo box is part of the main menu, so we'll use it's menu entry title for all boxes
config title="$1"

function start_checklist() {
    list \
        text='Hint: use space to select options in the list below' \
        prefix='alphanum' \
        callback='checklist_handler()'

    for i in {1..10}; do
        local summary='' selected='false'
        if [ "$i" -eq 5 ]; then
            summary='Option #5 is selected by default'
            selected='true'
        fi
        listEntry \
            title="Option #$i" \
            summary="$summary" \
            selected="$selected"
    done

    listDraw
}

function checklist_handler() {
    # Capture the status code from the list box
    local status=$? text
    if [ $status -eq 255 ]; then # Escape key pressed
        text='Exited with ESC.'
    elif [ $status -eq 1 ]; then # Cancel button pressed
        text='Canceled.'
    elif [ $# -eq 0 ]; then
        text="You didn't make any choice."
    else
        text="You chose:\n"
        for entry; do
            text+="$entry\n"
        done
    fi
    text text="$text"
}

start_checklist
