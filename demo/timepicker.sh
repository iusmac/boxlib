#!/usr/bin/env bash

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT"/../core.sh

# This demo box is part of the main menu, so we'll use it's menu entry title for all boxes
config title="$1"

if time="$(timepicker \
    timeFormat="Hour: %H\nMinute: %M\nSecond: %S")"; then
    text text="$time"
fi
