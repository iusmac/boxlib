#!/usr/bin/env bash

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT"/../core.sh

if time="$(timepicker \
    title='Example timepicker box' \
    timeFormat="Hour: %H\nMinute: %M\nSecond: %S")"; then
    text title='Picked time' text="$time"
fi
