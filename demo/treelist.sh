#!/usr/bin/env bash

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT"/../core.sh

# This demo box is part of the main menu, so we'll use it's menu entry title for all boxes
config title="$1"

list \
    type='tree' \
    text='Select a file or directory or press ESC to cancel' \
    [ title='/'                    summary='(root)'      depth=0                 ] \
    [ title='/foo'                 summary='foo/'        depth=1                 ] \
    [ title='/foo/bar'             summary='bar/'        depth=2                 ] \
    [ title='/foo/bar/example.txt' summary='example.txt' depth=3 selected='true' ] \
    [ title='/foo/path'            summary='path/'       depth=2                 ] \
    [ title='/file.txt'            summary='file.txt'    depth=0                 ]

if entry="$(listDraw)" && [ -n "$entry" ]; then
    text text="You selected path: $entry"
else
    text text="You didn't make any selection."
fi
