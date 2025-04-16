#!/usr/bin/env bash

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT"/../core.sh

# This demo box is part of the main menu, so we'll use it's menu entry title for all boxes
config title="$1"

function start_menu() {
    # NOTE: this menu loop is handcrafted rather then using the builtin loop=true option. This
    # ensures that each new loop cycle will re-renderer the entries summary that display the
    # last result stored in an exported variable
    local code=0
    while [ $code -eq 0 ]; do
        menu \
            text='Please, select an option or press ESC to exit' \
            propagateCallbackExitCode='false'

        menuEntry \
            title='Example task' \
            summary="Processed elements: ${LAST_TASK_STATUS:-Unknown}" \
            callback='task_handler()'

        menuEntry \
            title='Example radio list' \
            summary='Select me to jump to a radio list' \
            callback="$ROOT/radiolist.sh"

        menuEntry \
            title='Example check list' \
            summary='Select me to jump to a check list' \
            callback="$ROOT/checklist.sh"

        # Stop the menu loop rendering when user canceled the box. This requires the
        # propagateCallbackExitCode=false option to get the exit code from Whiptail/Dialog
        menuDraw; code=$?
    done
    return $code
}

function task_handler() {
    source "$ROOT"/../demo/progress.sh "$1"
    # IMPORTANT: need to export the variable for the menu entry to see it
    export LAST_TASK_STATUS="$TASK_PROGRESS_RESULT/10"
}

start_menu
