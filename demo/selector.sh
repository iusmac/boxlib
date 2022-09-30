#!/usr/bin/env bash

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT"/../core.sh

# Force Whiptail as renderer
[ "${1:-}" = '1' ] && config rendererName='whiptail' rendererPath='whiptail'

# Pre-select this file in the selector box
init="$ROOT/${BASH_SOURCE[0]##*/}"
if result="$(selector \
    title='Example file/path selector box' \
    filepath="$init")"; then
    text title='Selected path' text="$result"
fi
