#!/usr/bin/env bash

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT"/../core.sh

# This demo box is part of the main menu, so we'll use it's menu entry title for all boxes
config title="$1"

if input=$(input \
    text='Please, press Enter to continue, or ESC exit' \
    value='Hello ')
then
    text text="Your input is ${#input} characters long. The input was:\n$input"
fi
