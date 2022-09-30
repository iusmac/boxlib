#!/usr/bin/env bash

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT"/../core.sh

# Force Whiptail as renderer
[ "${1:-}" = '1' ] && config rendererName='whiptail' rendererPath='whiptail'

list \
    type='build' \
    title='Example build list' \
    prefix='alphanum'

for i in {1..10}; do
    [ "$i" -eq 5 ] && selected='true' || selected='false'
    listEntry \
        title="$i" \
        summary="Option #$i" \
        selected="$selected"
done

if result="$(listDraw)" && [ -n "$result" ]; then
    text title='Build list result' text="You chose:\n$result"
fi
