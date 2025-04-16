#!/usr/bin/env bash

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT"/../core.sh

# This demo box is part of the main menu, so we'll use it's menu entry title for all boxes
config title="$1"

list \
    type='build' \
    prefix='alphanum'

for i in {1..10}; do
    [ "$i" -eq 5 ] && selected='true' || selected='false'
    listEntry \
        title="$i" \
        summary="Option #$i" \
        selected="$selected"
done

if result="$(listDraw)" && [ -n "$result" ]; then
    text text="You chose:\n$result"
fi
