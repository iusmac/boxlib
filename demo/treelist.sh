#!/usr/bin/env bash

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT"/../core.sh

list \
    type='tree' \
    title='Example tree list box' \
    text='Select a file or directory or press ESC to cancel' \
    [ title='/'                    summary='(root)'      depth=0                 ] \
    [ title='/foo'                 summary='foo/'        depth=1                 ] \
    [ title='/foo/bar'             summary='bar/'        depth=2                 ] \
    [ title='/foo/bar/example.txt' summary='example.txt' depth=3 selected='true' ] \
    [ title='/foo/path'            summary='path/'       depth=2                 ] \
    [ title='/file.txt'            summary='file.txt'    depth=0                 ]

if entry="$(listDraw)" && [ -n "$entry" ]; then
    text="You selected path: $entry"
else
    text="You didn't make any selection."
fi
text title='Tree list result' text="$text"
