#!/usr/bin/env bash

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT"/../core.sh

# Force Whiptail as renderer
[ "${1:-}" = '1' ] && config rendererName='whiptail' rendererPath='whiptail'

# Display a copy of this file in the edit box
file="$ROOT/${BASH_SOURCE[0]##*/}"
if output="$(edit \
    title='Example edit box' \
    file="$file")"; then
    text title='File edit output' text="$output"
fi
