#!/usr/bin/env bash

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT"/../core.sh

# This demo box is part of the main menu, so we'll use it's menu entry title for all boxes
config title="$1"

# Display a copy of this file in the edit box
file="$ROOT/${BASH_SOURCE[0]##*/}"
if output="$(edit \
    file="$file")"; then
    text text="$output"
fi
