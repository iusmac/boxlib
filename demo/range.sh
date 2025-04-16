#!/usr/bin/env bash

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT"/../core.sh

if value="$(range \
    title='Example range box' \
    text='Select a value in range' \
    min=0 \
    max=10 \
    default=5)"; then
    text title='Selected range value' text="$value"
fi
