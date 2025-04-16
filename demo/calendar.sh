#!/usr/bin/env bash

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT"/../core.sh

if date="$(calendar \
    title='Example calendar box' \
    dateFormat="Day: %d\nMonth: %h\nYear: %Y")"; then
    text title='Picked date' text="$date"
fi
