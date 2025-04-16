#!/usr/bin/env bash

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT"/../core.sh

# This demo box is part of the main menu, so we'll use it's menu entry title for all boxes
config title="$1"

if value="$(range \
    text='Select a value in range' \
    min=0 \
    max=10 \
    default=5)"; then
    text text="Selected value: $value"
fi
