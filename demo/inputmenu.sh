#!/usr/bin/env bash

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT"/../core.sh

# Force Whiptail as renderer
[ "${1:-}" = '1' ] && config rendererName='whiptail' rendererPath='whiptail'

menu \
    title='Example input menu' \
    text='Please, select an option or rename. Press ESC to exit' \
    rename='true'

menuEntry \
    title='Apple' \
    summary='Amount: 30'

menuEntry \
    title='Mango' \
    summary='Amount: 5'

menuEntry \
    title='Grape' \
    summary='Amount: 7'

result="$(menuDraw)"; code=$?
if [ $code -eq 0 ]; then # The user selected the entry without making any changes
    text title='Result' text="You selected: $result"
elif [ $code -eq 3 ]; then # After renaming the exit code is equal to 3
    # Strip off the prefix from the output, which is in format: RENAMED <entry> <summary>
    result="${result#RENAMED }"
    entry="${result%% *}"
    summary="${result#* }"
    text title='Result' text="You've changed $entry to $summary"
fi
