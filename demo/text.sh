#!/usr/bin/env bash

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT"/../core.sh

# This demo box is part of the main menu, so we'll use it's menu entry title for all boxes
config title="$1"

text \
    text="Lorem ipsum dolor sit amet, consectetur adipiscing elit.\n" \
    text+="Praesent viverra felis ut tortor semper tincidunt ac a lorem.\n" \
    text+="Fusce vitae." \
    okLabel='Press Enter to close'; code=$?

if [ $code -eq 255 ]; then # Escape key pressed
    text text='Text box was canceled.'
else
    text text='Text box exited by user.'
fi

exit $code
