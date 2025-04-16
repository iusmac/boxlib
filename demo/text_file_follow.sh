#!/usr/bin/env bash

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT"/../core.sh

# This demo box is part of the main menu, so we'll use it's menu entry title for all boxes
config title="$1"

file="$(mktemp)" || exit $?

# Simulate a program working in the background and writing logs to file
{
    # Clean up the temp file on script exit
    trap 'rm "$file"' EXIT

    for i in {5..1}; do
        echo "Elements left to process: $i"
        sleep 1
        if [ "$i" -eq 1 ]; then
            echo 'Done.'
        fi
    done > "$file"
} &

text \
    file="$file" \
    follow='true' \
    width=50% \
    height=50%
