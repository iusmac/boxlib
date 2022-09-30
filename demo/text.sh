#!/usr/bin/env bash

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT"/../core.sh

# Force Whiptail as renderer
[ "${1:-}" = '1' ] && config rendererName='whiptail' rendererPath='whiptail'

text \
    title='Example text box' \
    text="Lorem ipsum dolor sit amet, consectetur adipiscing elit.\nPraesent viverra felis ut tortor semper tincidunt ac a lorem.\nFusce vitae." \
    okLabel='Press Enter to close'; code=$?

if [ $code -eq 255 ]; then # Escape key pressed
    text='Text box was canceled.'
else
    text='Text box exited by user.'
fi
text title='Text box result' text="$text"

exit $code
