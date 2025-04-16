#!/usr/bin/env bash

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT"/../core.sh

# This demo box is part of the main menu, so we'll use it's menu entry title for all boxes
config title="$1"

# Pre-select this file in the selector box
init="$ROOT/${BASH_SOURCE[0]##*/}"
if result="$(selector \
    filepath="$init")"; then
    text text="Selected path: $result"
fi
