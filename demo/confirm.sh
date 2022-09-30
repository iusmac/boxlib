#!/usr/bin/env bash

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT"/../core.sh

# Force Whiptail as renderer
[ "${1:-}" = '1' ] && config rendererName='whiptail' rendererPath='whiptail'

confirm \
    title='Example confirm box' \
    text="$(cat << EOF
You take the blue pill, the story ends.
You take the red pill, you stay in Wonderland.
EOF
)" yesLabel='Red pill' noLabel='Blue pill'; code=$?

case $code in
    0) text='You chose: Red Pill';;
    1) text='You chose: Blue Pill';;
    255) text='You chose: Black Pill' # Escape key pressed
esac
text title='Confirm box result' text="$text"

exit $code
