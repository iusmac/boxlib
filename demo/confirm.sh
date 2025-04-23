#!/usr/bin/env bash

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT"/../core.sh

# This demo box is part of the main menu, so we'll use it's menu entry title for all boxes
config title="$1"

confirm \
    text="You take the blue pill, the story ends.\n" \
    text+="You take the red pill, you stay in Wonderland." \
    yesLabel='Red pill' noLabel='Blue pill'; code=$?

case $code in
    0) text text='You chose: Red Pill';;
    1) text text='You chose: Blue Pill';;
    255) text text='You chose: Black Pill' # Escape key pressed
esac

exit $code
