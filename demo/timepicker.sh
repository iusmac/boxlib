#!/usr/bin/env bash

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT"/../core.sh

# Force Whiptail as renderer
[ "${1:-}" = '1' ] && config rendererName='whiptail' rendererPath='whiptail'

if time="$(timepicker \
    title='Example timepicker box' \
    timeFormat="Hour: %H\nMinute: %M\nSecond: %S")"; then
    text title='Picked time' text="$time"
fi
